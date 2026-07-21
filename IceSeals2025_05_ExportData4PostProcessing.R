# Ice seals 2025: Export image lists and detection files for post-processing (by flight, not survey_id)

# Create functions -----------------------------------------------
# Function to install packages needed
install_pkg <- function(x) {
  if (!require(x, character.only = TRUE)) {
    install.packages(x, dep = TRUE)
    if (!require(x, character.only = TRUE)) stop("Package not found")
  }
}

# Install libraries ----------------------------------------------
install_pkg("RPostgreSQL")
install_pkg("tidyverse")

# Extract data from DB ------------------------------------------------------------------
con <- RPostgreSQL::dbConnect(
  PostgreSQL(),
  dbname = Sys.getenv("pep_db"),
  host = Sys.getenv("pep_ip"),
  user = Sys.getenv("pep_admin"),
  password = Sys.getenv("admin_pw")
)

annotations <- RPostgreSQL::dbGetQuery(
  con,
  "SELECT * FROM surv_ice_seals_2025.tbl_detections_processed_rgb"
) %>%
  filter(
    detection_type != 'false_positive' &
      detection_type != 'off_frame' &
      detection_type != 'extra_detection' &
      detection_type != 'human' &
      detection_type != 'not_discernible' &
      detection_type != 'no_rgb'
  ) %>%
  select(
    -id,
    -detection_file,
    -species_confidence,
    -age_class,
    -age_class_confidence,
    -flag
  )

images <- RPostgreSQL::dbGetQuery(
  con,
  "SELECT image_name, image_dir FROM surv_ice_seals_2025.tbl_images"
)

datasets <- annotations %>%
  select(flight, camera_view) %>%
  unique()

annotations_withPath <- annotations %>%
  left_join(images, by = 'image_name') %>%
  mutate(image_name = paste0(image_dir, '/', image_name)) %>%
  mutate(
    image_name = sub('//akc0ss-n086/NMML_Polar_Imagery_4', 'S:', image_name)
  )


# Process data from each flight
for (i in 1:nrow(datasets)) {
  flight_i <- datasets$flight[i]
  camera_view_i <- datasets$camera_view[i]

  export <- annotations_withPath %>%
    filter(flight == flight_i, camera_view == camera_view_i) %>%
    group_by(flight, camera_view) %>%
    mutate(detection = row_number() - 1) %>%
    ungroup() %>%
    group_by(flight, camera_view, image_name) %>%
    mutate(frame_number = cur_group_id() - 1) %>%
    ungroup() %>%
    mutate(
      processed_detection_id = paste0("(trk-atr) ", processed_detection_id)
    ) %>%
    select(-flight, -camera_view, -image_dir)

  write.table(
    export,
    paste0(
      "C:\\smk\\IceSeals_2025_DetectionFiles4PostProcessing\\ice_seals_2025",
      '_',
      datasets$flight[i],
      '_',
      datasets$camera_view[i],
      "_animalOnlyDetections_",
      format(Sys.Date(), '%Y%m%d'),
      ".csv"
    ),
    row.names = FALSE,
    quote = FALSE,
    col.names = FALSE,
    sep = ","
  )
}

# Disconnect for database and delete unnecessary variables ------------------------------
dbDisconnect(con)
rm(con)
