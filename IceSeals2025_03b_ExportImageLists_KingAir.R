# Process Ice Seals 2025 original IR detections for review

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "\\\\akc0ss-n086\\NMML_Polar\\Data\\Annotations\\ice_seals_2025_202603_batchProcessing_KingAir\\"
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
  filter(flight > 'fl200') %>% # only King Air images
  filter(ir_nuc == "N") %>% # exclude NUC IR
  filter(rgb_imagezero == "N") # exclude 0-sized RGB frames

images_ir <- images %>%
  filter(image_type == 'ir_image')

images_rgb <- images %>%
  filter(image_type == 'rgb_image') 

flight_cv <- images_ir %>%
  select(flight, camera_view) %>%
  unique()

# Generate image lists and export to LAN
for (i in 1:nrow(flight_cv)) {
  flight_i <- flight_cv$flight[i]
  camera_view_i <- flight_cv$camera_view[i]
  
  export_images_ir <- images_ir %>%
    filter(flight == flight_i & camera_view == camera_view_i) %>%
    select(image_path) %>%
    unique() %>%
    arrange(image_path)
  
  export_images_rgb <- export_images_ir %>%
    mutate(image_path = str_replace(image_path, "ir.tif", "rgb.jpg")) %>%
    filter(image_path %in% images_rgb$image_path)
  
  export_folder <- paste("ice_seals_2025", flight_i, camera_view_i, sep = "_")
  dir.create(export_folder)
  
  write.table(export_images_ir, paste(wd, export_folder, paste("ice_seals_2025", flight_i, camera_view_i, "ir_images.txt", sep = "_"), sep = "/"), 
              quote = FALSE, row.names = FALSE, col.names = FALSE)
  write.table(export_images_rgb, paste(wd, export_folder, paste("ice_seals_2025", flight_i, camera_view_i, "rgb_images.txt", sep = "_"), sep = "/"), 
              quote = FALSE, row.names = FALSE, col.names = FALSE)
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)