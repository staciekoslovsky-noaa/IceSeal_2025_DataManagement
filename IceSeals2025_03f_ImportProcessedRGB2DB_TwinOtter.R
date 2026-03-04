# Ice Seals 2025: Import processed thermal detections to DB (Twin Otter)

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "O:\\Data\\Annotations\\ice_seals_2025_202509_inFlightDetections_TwinOtter"

# Set up working environment
"%notin%" <- Negate("%in%")
setwd(wd)
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Delete data from tables (if needed)
RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_ice_seals_2025.tbl_detections_processed_rgb WHERE flight < \'fl200\'")

# Import data and process
folders <- data.frame(folder_path = list.dirs(path = wd, full.names = TRUE, recursive = FALSE), stringsAsFactors = FALSE)
folders <- folders %>%
  mutate(flight = str_extract(folder_path, "fl[0-9][0-9][0-9]"),
         camera_view = gsub("_", "", str_extract(folder_path, "_[A-Z]$")))

for (i in 1:nrow(folders)) {
  if (i == 1) {
    processed_id <- data.frame(max = 0)
  } else {
    processed_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_ice_seals_2025.tbl_detections_processed_rgb")
    processed_id$max <- ifelse(is.na(processed_id$max), 0, processed_id$max)
  }
  
  files <- list.files(folders$folder_path[i])
  rgb_validated <- files[grepl('_rgb_irDetectionsTransposed_processed', files)] 
  if(length(rgb_validated) == 0) next
  
  processed <- read.csv(paste(folders$folder_path[i], rgb_validated, sep = "\\"), skip = 2, header = FALSE, stringsAsFactors = FALSE, col.names = c("detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", 
                                                                                                                                                    "att1", "att2", "att3", "att4"))
  
  processed <- data.frame(lapply(processed, function(x) {gsub("\\(trk-atr\\) *", "", x)})) %>%
    mutate(image_name = basename(sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)]))) %>%
    mutate(id = 1:n() + processed_id$max) %>%
    mutate(detection_file = rgb_validated) %>%
    mutate(flight = folders$flight[i]) %>%
    mutate(camera_view = folders$camera_view[i]) %>%
    mutate(processed_detection_id = paste("surv_ice_seals_2025", flight, camera_view, detection, sep = "_")) %>%
    mutate(species_confidence = ifelse(grepl("^species_confidence", att1), gsub("species_confidence *", "", att1),
                                       ifelse(grepl("^species_confidence", att2), gsub("species_confidence *", "", att2),
                                              ifelse(grepl("^species_confidence", att3), gsub("species_confidence *", "", att3), "NA")))) %>%
    mutate(age_class = ifelse(grepl("^age_class[[:space:]]", att1), gsub("age_class *", "", att1),
                              ifelse(grepl("^age_class[[:space:]]", att2), gsub("age_class *", "", att2),
                                     ifelse(grepl("^age_class[[:space:]]", att3), gsub("age_class *", "", att3), "NA")))) %>%
    mutate(age_class_confidence = ifelse(grepl("^age_class_confidence", att1), gsub("age_class_confidence *", "", att1),
                                         ifelse(grepl("^age_class_confidence", att2), gsub("age_class_confidence *", "", att2),
                                                ifelse(grepl("^age_class_confidence", att3), gsub("age_class_confidence *", "", att3), "NA")))) %>%
    mutate(flag = ifelse(grepl("^flag", att1), gsub("flag *", "", att1),
                                         ifelse(grepl("^flag", att2), gsub("flag *", "", att2),
                                                ifelse(grepl("^flag", att3), gsub("flag *", "", att3), "NA")))) %>%
    mutate(bound_left = as.integer(bound_left),
           bound_right = as.integer(bound_right),
           bound_top = as.integer(bound_top),
           bound_bottom = as.integer(bound_bottom)) %>%
    select("id", "detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", 
           "flight", "camera_view", "processed_detection_id", "detection_file",
           "species_confidence", "age_class", "age_class_confidence", "flag")
  
  # Import data to DB
  RPostgreSQL::dbWriteTable(con, c("surv_ice_seals_2025", "tbl_detections_processed_rgb"), processed, append = TRUE, row.names = FALSE)
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
