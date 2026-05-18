# Process Ice Seals 2025 original IR detections to DB

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
#wd <- "O:\\Data\\Annotations\\ice_seals_2025_202603_batchProcessing_KingAir"
wd <- "O:\\Data\\Annotations\\ice_seals_2025_202509_inFlightDetections_TwinOtter"

# Set up working environment
"%notin%" <- Negate("%in%")
setwd(wd)
con <- RPostgreSQL::dbConnect(
  PostgreSQL(),
  dbname = Sys.getenv("pep_db"),
  host = Sys.getenv("pep_ip"),
  user = Sys.getenv("pep_admin"),
  password = Sys.getenv("admin_pw")
)

# Delete data from tables (if needed)
# RPostgreSQL::dbSendQuery(
#   con,
#   "DELETE FROM surv_ice_seals_2025.tbl_detections_original_ir"
# )

# Import data and process
folders <- data.frame(
  folder_path = list.dirs(path = wd, full.names = TRUE, recursive = FALSE),
  stringsAsFactors = FALSE
)
folders <- folders %>%
  mutate(
    flight = str_extract(folder_path, "fl[0-9][0-9][0-9]"),
    camera_view = gsub("_", "", str_extract(folder_path, "_[A-Z]$"))
  )

for (i in 1:nrow(folders)) {
  if (i == 1) {
    original_id <- data.frame(max = 0)
  } else {
    original_id <- RPostgreSQL::dbGetQuery(
      con,
      "SELECT max(id) FROM surv_ice_seals_2025.tbl_detections_original_ir"
    )
    original_id$max <- ifelse(is.na(original_id$max), 0, original_id$max)
  }

  files <- list.files(folders$folder_path[i])
  ir_original <- files[grepl('ir_detections.csv', files)]
  if (identical(ir_original, character(0))) {
    next
  }

  original <- read.csv(
    paste(folders$folder_path[i], ir_original, sep = "\\"),
    skip = 2,
    header = FALSE,
    stringsAsFactors = FALSE,
    col.names = c(
      "detection",
      "image_name",
      "frame_number",
      "bound_left",
      "bound_top",
      "bound_right",
      "bound_bottom",
      "score",
      "length",
      "detection_type",
      "type_score",
      "detection_comments"
    )
  )
  original <- original %>%
    mutate(
      image_name = sapply(strsplit(image_name, split = "\\/"), function(x) {
        #x[length(x)]
        basename(x)
      })
    ) %>%
    mutate(id = 1:n() + original_id$max) %>%
    mutate(detection_file = ir_validated) %>%
    mutate(flight = folders$flight[i]) %>%
    mutate(camera_view = folders$camera_view[i]) %>%
    mutate(
      processed_detection_id = paste(
        "surv_ice_seals_2025",
        flight,
        camera_view,
        detection,
        sep = "_"
      )
    ) %>%
    select(
      "id",
      "detection",
      "image_name",
      "frame_number",
      "bound_left",
      "bound_top",
      "bound_right",
      "bound_bottom",
      "score",
      "length",
      "detection_type",
      "type_score",
      "flight",
      "camera_view",
      "processed_detection_id",
      "detection_file",
      "detection_comments"
    ) %>%
    mutate(
      detection_type = ifelse(
        detection_type == 'off_ir',
        'animal_off_ir',
        detection_type
      )
    )

  # Import data to DB
  RPostgreSQL::dbWriteTable(
    con,
    c("surv_ice_seals_2025", "tbl_detections_original_ir"),
    original,
    append = TRUE,
    row.names = FALSE
  )
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
