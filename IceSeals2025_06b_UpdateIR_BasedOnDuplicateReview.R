# Import and process duplicate detections in the DB
# S. Koslovsky, August 2026

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

# Process duplicate detection CSV (downloaded from this file: https://docs.google.com/spreadsheets/d/1-CpDh1PXACCoT0l2qsOV0RTLkFsm83ZRFu6mMSYSP-E/edit?gid=0#gid=0)
data <- read.csv(
  "C:\\Users\\Stacie.Hardy\\Downloads\\IceSeals2025_DuplicateDetectionReview_20260807.csv"
) %>%
  select(processed_detection_id, update_to_detection_type_ir, smk_review) %>%
  rename(duplicate_review_comments = smk_review) %>%
  rename(new_detection_type_ir = update_to_detection_type_ir)

RPostgreSQL::dbWriteTable(
  con,
  c("surv_ice_seals_2025", "tbl_detections_duplicate_ir"),
  data,
  row.names = FALSE,
  append = TRUE
)

RPostgreSQL::dbSendQuery(
  con,
  "UPDATE surv_ice_seals_2025.tbl_detections_processed_ir i
 SET detection_type = d.new_detection_type_ir
 FROM surv_ice_seals_2025.tbl_detections_duplicate_ir d
 WHERE i.processed_detection_id = d.processed_detection_id
 "
)
