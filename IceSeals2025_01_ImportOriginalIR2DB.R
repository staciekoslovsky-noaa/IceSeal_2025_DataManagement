# Process Ice Seals 2025 original IR detections to DB

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "\\\\akc0ss-n086\\NMML_Polar_Imagery_4\\Surveys_IceSeals_2025"

# Set up working environment
"%notin%" <- Negate("%in%")
setwd(wd)
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Delete data from tables (if needed)
RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_ice_seals_2025.tbl_detections_original_ir")

# Import data and process
folders <- data.frame(folder_path = list.dirs(path = wd, full.names = TRUE, recursive = FALSE), stringsAsFactors = FALSE)
folders <- folders %>%
  mutate(flight = str_extract(folder_path, "fl[0-9][0-9][0-9]"),
         folder_path = paste0(folder_path, "/detections")) %>%
  filter(flight < 'fl200') %>% # only Twin Otter flights
  filter(!str_detect(folder_path, "transit")) %>% # no transit flights
  filter(!str_detect(folder_path, "after")) %>% # no anomolous data
  filter(!str_detect(folder_path, "calibration")) %>% # no calibration data
  filter(!str_detect(folder_path, "adfg")) %>% # no adfg data
  filter(flight >= 'fl107') # Twin Otter flights without issues

for (i in 1:nrow(folders)) {
  files <- list.files(folders$folder_path[i])
  ir_original <- files[grepl('csv', files)] 
  
  for (f in 1:length(ir_original)) {
    ir_file <- ir_original[f]
    
    original_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_ice_seals_2025.tbl_detections_original_ir")
    if(is.na(original_id)) { original_id$max <- 0 } 
    
    original <- read.csv(paste(folders$folder_path[i], ir_file, sep = "\\"), skip = 2, header = FALSE, stringsAsFactors = FALSE, col.names = c("detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score"))
    if(nrow(original) == 0) next
    
    original <- original %>%
      mutate(image_name = sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)])) %>%
      mutate(id = 1:n() + original_id$max) %>%
      mutate(detection_file = ir_file) %>%
      mutate(flight = folders$flight[i]) %>%
      mutate(camera_view = strsplit(ir_file, "_")[[1]][2]) %>%
      mutate(detection_id = paste("surv_ice_seals_2025", flight, camera_view, paste(f, sprintf("%05d", detection), sep = "."), sep = "_")) %>%
      select("id", "detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", "flight", "camera_view", "detection_id", "detection_file")
    
    # Import data to DB
    RPostgreSQL::dbWriteTable(con, c("surv_ice_seals_2025", "tbl_detections_original_ir"), original, append = TRUE, row.names = FALSE)
    
  }

}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)