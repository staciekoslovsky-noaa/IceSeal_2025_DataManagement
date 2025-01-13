# Ice Seals 2025: Identify empty frames
# S. Koslovsky

# Create functions -----------------------------------------------
# Function to install packages needed
install_pkg <- function(x)
{
  if (!require(x,character.only = TRUE))
  {
    install.packages(x,dep=TRUE)
    if(!require(x,character.only = TRUE)) stop("Package not found")
  }
}

# Install libraries ----------------------------------------------
install_pkg("RPostgreSQL")
install_pkg("rjson")
install_pkg("plyr")
install_pkg("stringr")


# Get data from DB
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Get list of images from DB images and calculate file size
images <- RPostgreSQL::dbGetQuery(con, "SELECT image_dir || \'\\' || image_name AS image FROM surv_ice_seals_2025.tbl_images WHERE image_type = \'rgb_image\'")
file_details <- file.info(images$image)
file_details$image_path <- rownames(file_details)
rownames(file_details) <- NULL

file_details2DB <- file_details %>%
  mutate(image_name = basename(image_path)) %>%
  mutate(flight = str_extract(image_name, "fl[0-9][0-9][0-9]"),
         camera_view = gsub("_", "", str_extract(image_name, "_[A-Z]_")),
         dt = str_extract(image_name, "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9]")) %>%
  mutate(rgb_imagezero = ifelse(size == 0, "Y", "N")) 


# Update database with results
RPostgreSQL::dbSendQuery(con, "ALTER TABLE surv_ice_seals_2025.tbl_images ADD COLUMN IF NOT EXISTS rgb_imagezero VARCHAR(10)")
RPostgreSQL::dbSendQuery(con, "UPDATE surv_ice_seals_2025.tbl_images SET rgb_imagezero = NULL")

for (i in 1:nrow(file_details2DB)) {
  sql <- paste0("UPDATE surv_ice_seals_2025.tbl_images SET rgb_imagezero = \'", file_details2DB$rgb_imagezero[i], 
                "\' WHERE flight = \'", file_details2DB$flight[i], 
                "\' AND camera_view = \'", file_details2DB$camera_view[i], 
                "\' AND dt = \'", file_details2DB$dt[i], "\'")
  RPostgreSQL::dbSendQuery(con, sql)
}

RPostgreSQL::dbSendQuery(con, paste0("UPDATE surv_ice_seals_2025.tbl_images SET rgb_imagezero = \'NA\' WHERE rgb_imagezero IS NULL"))



RPostgreSQL::dbDisconnect(con)