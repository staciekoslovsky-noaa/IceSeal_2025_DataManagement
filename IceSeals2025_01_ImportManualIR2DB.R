# Process Ice Seals 2025 original IR detections to DB

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "\\\\akc0ss-n086\\NMML_Polar\\Data\\Annotations\\ice_seals_2025_202505_manualReviewIR_X"

# Set up working environment
"%notin%" <- Negate("%in%")
setwd(wd)
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Delete data from tables (if needed)
RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_ice_seals_2025.tbl_detections_manual_ir")

# Import data and process
files <- list.files(wd)
ir_manual <- files[grepl('csv', files)] 
  
for (f in 1:length(ir_manual)) {
  ir_file <- ir_manual[f]
  
  manual_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_ice_seals_2025.tbl_detections_manual_ir")
  if(is.na(manual_id)) { manual_id$max <- 0 } 
  
  manual <- read.csv(ir_file, skip = 2, header = FALSE, stringsAsFactors = FALSE, col.names = c("detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", "comments"))
  if(nrow(manual) == 0) next
  
  manual <- manual %>%
    mutate(image_name = sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)])) %>%
    mutate(id = 1:n() + manual_id$max) %>%
    mutate(detection_file = ir_file) %>%
    mutate(flight = sapply(image_name, function(x) unlist(strsplit(x, "_"))[[4]])) %>%
    mutate(camera_view = sapply(image_name, function(x) unlist(strsplit(x, "_"))[[5]])) %>%
    mutate(detection_id = paste("surv_ice_seals_2025", flight, camera_view, paste(f, sprintf("%05d", detection), sep = "."), sep = "_")) %>%
    select("id", "detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", "comments", "flight", "camera_view", "detection_id", "detection_file")
  
  # Import data to DB
  RPostgreSQL::dbWriteTable(con, c("surv_ice_seals_2025", "tbl_detections_manual_ir"), manual, append = TRUE, row.names = FALSE)
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)