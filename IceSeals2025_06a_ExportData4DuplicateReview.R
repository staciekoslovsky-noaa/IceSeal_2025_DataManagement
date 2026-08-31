# Create image lists and detection files for review of 2025 ice seals duplicates
# S. Koslovsky, August 2026

# Next time you have to do this, use the dupes list to make the list of images that need to be reviewed, then pull all the detections on those frames -- will make it easier to see what's actually going on...

# Load packages
library(tidyverse)
library(RPostgreSQL)

# Connect to database
con <- RPostgreSQL::dbConnect(
  PostgreSQL(),
  dbname = Sys.getenv("pep_db"),
  host = Sys.getenv("pep_ip"),
  user = Sys.getenv("pep_admin"),
  password = Sys.getenv("admin_pw")
)

# Get images and duplicates from DB
# images_ir <- RPostgreSQL::dbGetQuery(
#   con,
#   "SELECT * FROM surv_ice_seals_2025.tbl_images WHERE image_type = 'ir_image'"
# )
images_rgb <- RPostgreSQL::dbGetQuery(
  con,
  "SELECT * FROM surv_ice_seals_2025.tbl_images WHERE image_type = 'rgb_image'"
)
dupes <- RPostgreSQL::dbGetQuery(
  con,
  "SELECT * FROM surv_ice_seals_2025.qa_duplicates"
)
RPostgreSQL::dbDisconnect(con)
rm(con)

# Create image lists based on frames with duplicates
images_rgb_dupes <- images_rgb %>%
  arrange(image_name) %>%
  mutate(previous_image = lag(image_name)) %>%
  mutate(next_image = lead(image_name)) %>%
  select(image_dir, image_name, previous_image, next_image, image_group) %>%
  inner_join(dupes, by = c("image_name" = "image_name"))

images_rgb_list <- rbind(
  images_rgb_dupes %>% select(image_dir, image_name),
  images_rgb_dupes %>%
    select(image_dir, previous_image) %>%
    rename(image_name = previous_image),
  images_rgb_dupes %>%
    select(image_dir, next_image) %>%
    rename(image_name = next_image)
) %>%
  arrange(image_name) %>%
  unique()

images_rgb_forDupes <- images_rgb_list %>%
  select(image_name) %>%
  unique() %>%
  mutate(frame_number = row_number() - 1)

images_rgb_list <- images_rgb_list %>%
  mutate(image_path = paste(image_dir, image_name, sep = "/")) %>%
  select(image_path) %>%
  unique()

# images_ir_list <- images_ir %>%
#   inner_join(images_rgb_list, by = c("image_group" = "image_group")) %>%
#   mutate(image_path = paste(image_dir, image_name, sep = "/")) %>%
#   select(image_path) %>%
#   unique()

# Create detection file for review
dupes_processed <- dupes %>%
  arrange(image_name) %>%
  mutate(
    detection = row_number() - 1,
    score = 1,
    length = 1,
    type_score = 1
  ) %>%
  inner_join(images_rgb_forDupes, by = c("image_name" = "image_name")) %>%
  select(
    detection,
    image_name,
    frame_number,
    bound_left,
    bound_top,
    bound_right,
    bound_bottom,
    score,
    length,
    detection_type_ir,
    type_score,
    processed_detection_id
  )

# Export image lists and detection file
# write.table(
#   images_ir_list,
#   "C://smk/ice_seals_2025_dupes_ir_images.txt",
#   quote = FALSE,
#   row.names = FALSE,
#   col.names = FALSE
# )
write.table(
  images_rgb_list,
  "C://smk/ice_seals_2025_dupes_rgb_images.txt",
  quote = FALSE,
  row.names = FALSE,
  col.names = FALSE
)
write.table(
  dupes_processed,
  "C://smk/ice_seals_2025_dupes_rgbBB_irDetectionType.csv",
  sep = ",",
  quote = FALSE,
  row.names = FALSE,
  col.names = FALSE
)
