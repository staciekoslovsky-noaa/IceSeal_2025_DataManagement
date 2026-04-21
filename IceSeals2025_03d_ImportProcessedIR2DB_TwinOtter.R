# Ice Seals 2025: Import processed thermal detections to DB (Twin Otter)

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
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
RPostgreSQL::dbSendQuery(
  con,
  "DELETE FROM surv_ice_seals_2025.tbl_detections_processed_ir WHERE flight < 'fl200'"
)

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
    processed_id <- data.frame(max = 0)
  } else {
    processed_id <- RPostgreSQL::dbGetQuery(
      con,
      "SELECT max(id) FROM surv_ice_seals_2025.tbl_detections_processed_ir"
    )
    processed_id$max <- ifelse(is.na(processed_id$max), 0, processed_id$max)
  }

  files <- list.files(folders$folder_path[i])
  ir_validated <- files[grepl('ir_detections_validated', files)]
  if (identical(ir_validated, character(0))) {
    next
  }

  processed <- read.csv(
    paste(folders$folder_path[i], ir_validated, sep = "\\"),
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
  processed <- processed %>%
    mutate(
      image_name = sapply(strsplit(image_name, split = "\\/"), function(x) {
        x[length(x)]
      })
    ) %>%
    mutate(id = 1:n() + processed_id$max) %>%
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
    c("surv_ice_seals_2025", "tbl_detections_processed_ir"),
    processed,
    append = TRUE,
    row.names = FALSE
  )
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
