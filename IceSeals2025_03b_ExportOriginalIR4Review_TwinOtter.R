# Process Ice Seals 2025 original IR detections for review

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "\\\\akc0ss-n086\\NMML_Polar\\Data\\Annotations\\ice_seals_2025_202509_inFlightDetections\\"
## MANUALLY DELETE ALL FILES BEFORE RUNNING CODE!!

# Set up working environment
"%notin%" <- Negate("%in%")
setwd(wd)
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Get and filter images from DB
images <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM surv_ice_seals_2025.tbl_images_4list") %>%
  filter(flight < 'fl200') %>% # only Twin Otter images
  filter(flight > 'fl106') %>% # exclude problematic flights at beginning of project
  filter(ir_nuc == "N") %>% # exclude NUC IR
  filter(rgb_imagezero == "N") # exclude 0-sized RGB frames

images_ir <- images %>%
  filter(image_type == 'ir_image') # thermal images only

images_rgb <- images %>%
  filter(image_type == 'rgb_image') 

images_uv <- images %>%
  filter(image_type == 'uv_image') 

# Get associated bounding boxes from original IR detections from DB and filter to score >= 0.1
detections <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM surv_ice_seals_2025.tbl_detections_original_ir") %>%
  select(-flight, -camera_view)

# Join image and detection data
data <- images_ir %>%
  full_join(detections, "image_name") 

data_withoutImages <- data %>%
  filter(is.na(flight))

data_4review <- data %>%
  filter(score >= 0.1) %>%
  filter(detection_type == "Hotspot") %>% # frames with detections
  select(detection, image_name, frame_number, bound_left, bound_top, bound_right, bound_bottom, score, length, detection_type, type_score, detection_id, flight, camera_view, image_path) %>%
  arrange(flight, camera_view, image_name) 

flight_cv <- data_4review %>%
  select(flight, camera_view) %>%
  unique()

# Generate image lists and annotation files for IR images and detections (where images in detections and detections in images) and export to LAN
for (i in 1:nrow(flight_cv)) {
  flight_i <- flight_cv$flight[i]
  camera_view_i <- flight_cv$camera_view[i]
  
  export <- data_4review %>%
    filter(flight == flight_i,
           camera_view == camera_view_i) %>%
    group_by(flight, camera_view) %>%
    mutate(detection = row_number() - 1) %>%
    ungroup() %>%
    group_by(flight, camera_view, image_name) %>%
    mutate(frame_number = cur_group_id() - 1) %>%
    ungroup()
  
  export_images_ir <- export %>%
    select(image_path) %>%
    unique() %>%
    arrange(image_path)
  
  export_images_rgb <- export_images_ir %>%
    mutate(image_path = str_replace(image_path, "ir.tif", "rgb.jpg")) %>%
    filter(image_path %in% images_rgb$image_path)
  
  export_images_uv <- export_images_ir %>%
    mutate(image_path = str_replace(image_path, "ir.tif", "uv.jpg")) %>%
    filter(image_path %in% images_uv$image_path)
  
  export_annotations <- export %>%
    mutate(attribute = paste0("(trk-atr) detection_id ", detection_id)) %>%
    select(-flight, -camera_view, -image_path, -detection_id)
  
  export_folder <- paste("ice_seals_2025", flight_i, camera_view_i, sep = "_")
  dir.create(export_folder)
  
  write.table(export_images_ir, paste(wd, export_folder, paste("ice_seals_2025", flight_i, camera_view_i, "ir_images.txt", sep = "_"), sep = "/"), 
              quote = FALSE, row.names = FALSE, col.names = FALSE)
  write.table(export_images_rgb, paste(wd, export_folder, paste("ice_seals_2025", flight_i, camera_view_i, "rgb_images.txt", sep = "_"), sep = "/"), 
              quote = FALSE, row.names = FALSE, col.names = FALSE)
  write.table(export_images_uv, paste(wd, export_folder, paste("ice_seals_2025", flight_i, camera_view_i, "uv_images.txt", sep = "_"), sep = "/"), 
              quote = FALSE, row.names = FALSE, col.names = FALSE)
  write.table(export_annotations, paste(wd, export_folder, paste("ice_seals_2025", flight_i, camera_view_i, "ir_detections.csv", sep = "_"), sep = "/"), 
              sep = ",", quote = FALSE, row.names = FALSE, col.names = FALSE)
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)