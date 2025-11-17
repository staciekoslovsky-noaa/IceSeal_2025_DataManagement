# Process Ice Seals 2025 manual IR detections for training and validation

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "\\\\akc0ss-n086\\NMML_Polar\\Data\\Annotations\\ice_seals_2025_202505_manualReviewIR_X\\Formatted4Training"


# Set up working environment
set.seed(129)
"%notin%" <- Negate("%in%")

con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Reset ML image status field
RPostgreSQL::dbSendQuery(con, "UPDATE surv_ice_seals_2025.tbl_images SET ml_imagestatus_ir = NULL")

# Set ML image status for manually reviewed images and establish background images

images <- RPostgreSQL::dbGetQuery(con, "SELECT DISTINCT image_name
                                  FROM surv_ice_seals_2025.tbl_detections_manual_ir
                                  WHERE (detection_type LIKE \'%seal\' OR detection_type LIKE \'%pup\')")

selected_images <- sample(1:nrow(images), floor((nrow(images) * 0.7)))
images$ml_imagestatus_ir[selected_images] <- "training"
images <- images %>%
  mutate(ml_imagestatus_ir = ifelse(is.na(ml_imagestatus_ir), "validation", ml_imagestatus_ir)) %>%
  mutate(flight = sapply(image_name, function(x) unlist(strsplit(x, "_"))[[4]])) %>%
  mutate(camera_view = sapply(image_name, function(x) unlist(strsplit(x, "_"))[[5]])) %>%
  mutate(dt = sapply(image_name, function(x) paste(unlist(strsplit(x, "_"))[[6]], unlist(strsplit(x, "_"))[[7]], sep = "_")))

for (i in 1:nrow(images)) {
  RPostgreSQL::dbSendQuery(con, paste0("UPDATE surv_ice_seals_2025.tbl_images
                                       SET ml_imagestatus_ir = \'", images$ml_imagestatus_ir[i],
                                       "\' WHERE flight = \'", images$flight[i],
                                       "\' AND camera_view = \'", images$camera_view[i], 
                                       "\' AND dt = \'", images$dt[i], "\'"))
}

background_images <- RPostgreSQL::dbGetQuery(con, "SELECT dt, image_group, image_name
                                             FROM surv_ice_seals_2025.tbl_images
                                             WHERE ml_imagestatus_ir IS NULL AND image_type = \'ir_image\' AND ir_manualreview = \'Y\'
                                             AND ir_nuc = \'N\' AND rgb_imagezero = \'N\'
                                             AND dt NOT IN 
                                             (SELECT dt FROM surv_ice_seals_2025.tbl_images 
                                             WHERE ml_imagestatus_ir = \'training\' OR ml_imagestatus_ir = \'validation\')") %>%
  group_by(dt) %>%
  mutate(dt_id = cur_group_id()) %>%
  ungroup() %>%
  group_by(dt_id) %>%
  mutate(dt_id_id = row_number()) %>%
  ungroup()

background_sample <- data.frame(dt_id_selected = sample(1:max(background_images$dt_id), size = 1000, replace = FALSE)) %>%
  inner_join(background_images %>% group_by(dt_id) %>% summarise(max_images = max(dt_id_id, na.rm = TRUE)), by = join_by(dt_id_selected == dt_id)) %>%
  mutate(dt_id_id_selected = sapply(max_images, function(x) sample(1:x, size = 1, replace = TRUE))) %>%
  select(-max_images)

background <- background_images %>%
  inner_join(background_sample, by = join_by(dt_id == dt_id_selected, dt_id_id == dt_id_id_selected)) %>%
  select(image_group, image_name) %>%
  mutate(ml_imagestatus_ir = "background") #%>%
  # mutate(flight = sapply(image_name, function(x) unlist(strsplit(x, "_"))[[4]])) %>%
  # mutate(camera_view = sapply(image_name, function(x) unlist(strsplit(x, "_"))[[5]])) %>%
  # mutate(dt = sapply(image_name, function(x) paste(unlist(strsplit(x, "_"))[[6]], unlist(strsplit(x, "_"))[[7]], sep = "_")))

for (i in 1:nrow(background)) {
  RPostgreSQL::dbSendQuery(con, paste0("UPDATE surv_ice_seals_2025.tbl_images
                                       SET ml_imagestatus_ir = \'", background$ml_imagestatus_ir[i],
                                       "\' WHERE image_group = ", background$image_group[i]))
}

# Get images and detections from DB
# training data
images2export_training <- RPostgreSQL::dbGetQuery(con, "SELECT image_dir || \'\\\' || image_name AS image_path, image_name FROM surv_ice_seals_2025.tbl_images 
                                          WHERE (ml_imagestatus_ir = \'background\' OR ml_imagestatus_ir = \'training\')
                                          AND image_type = \'ir_image\'") 
images2export_training <- images2export_training %>%
  arrange(image_name) %>%
  mutate(image_id = row_number() - 1) #1:nrow(images2export_training) - 1)#as.numeric(row.names(images2export_training)) - 1)

detections2export_training <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM surv_ice_seals_2025.tbl_detections_manual_ir
                                             WHERE detection_type LIKE \'%seal\' OR detection_type LIKE \'%pup\'") 
detections2export_training <- detections2export_training %>%
  filter(image_name %in% basename(images2export_training$image_name)) %>%
  arrange(image_name) %>%
  left_join(images2export_training, by = "image_name") %>%
  mutate(frame_number = image_id) %>%
  mutate(detection = row_number() - 1) %>%
  select(-id, -comments, -flight, -camera_view, -detection_id, -detection_file, -image_path, -image_id)

images2export_training <- images2export_training %>%
  select(image_path)

images2export_training_rgb <- images2export_training %>%
  mutate(image_path = str_replace(image_path, "ir.tif", "rgb.jpg"))

# validation data
images2export_validation <- RPostgreSQL::dbGetQuery(con, "SELECT image_dir || \'\\\' || image_name AS image_path, image_name FROM surv_ice_seals_2025.tbl_images 
                                          WHERE ml_imagestatus_ir = \'validation\' AND image_type = \'ir_image\'")
images2export_validation <- images2export_validation %>%
  arrange(image_name) %>%
  mutate(image_id = row_number() - 1)

detections2export_validation <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM surv_ice_seals_2025.tbl_detections_manual_ir
                                                      WHERE (detection_type LIKE \'%seal\' OR detection_type LIKE \'%pup\')
                                                            AND image_name IN (SELECT image_name FROM surv_ice_seals_2025.tbl_images
                                                            WHERE ml_imagestatus_ir = \'validation\' AND image_type = \'ir_image\')") 
detections2export_validation <- detections2export_validation %>%
  filter(image_name %in% basename(images2export_validation$image_name)) %>%
  arrange(image_name) %>%
  left_join(images2export_validation, by = "image_name") %>%
  mutate(frame_number = image_id) %>%
  mutate(detection = row_number() - 1) %>%
  select(-id, -comments, -flight, -camera_view, -detection_id, -detection_file, -image_path, -image_id)

images2export_validation <- images2export_validation %>%
  select(image_path)

images2export_validation_rgb <- images2export_validation %>%
  mutate(image_path = str_replace(image_path, "ir.tif", "rgb.jpg"))

# Export data to LAN
setwd(wd)
write.table(images2export_training, "ice_seals_2025_irTraining_ir_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(images2export_training_rgb, "ice_seals_2025_irTraining_rgb_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(detections2export_training, "ice_seals_2025_irTraining_ir_detections.csv", sep = ",", quote = FALSE, row.names = FALSE, col.names = FALSE)

write.table(images2export_validation, "ice_seals_2025_irValidation_ir_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(images2export_validation_rgb, "ice_seals_2025_irValidation_rgb_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(detections2export_validation, "ice_seals_2025_irValidation_ir_detections.csv", sep = ",", quote = FALSE, row.names = FALSE, col.names = FALSE)

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
