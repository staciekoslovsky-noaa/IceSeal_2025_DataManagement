# Ice Seals 2025: Process Data/Images to DB
# S. Koslovsky

# Set Working Variables
wd <- "//akc0ss-n086/NMML_Polar_Imagery_4/Surveys_IceSeals_2025"
metaTemplate <- "//akc0ss-n086/NMML_Polar_Imagery_4/Surveys_IceSeals_2025/Template4Import.json"
projectPrefix <- "ice_seals_2025"

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

# Run code -------------------------------------------------------
setwd(wd)

# Connect to PostgreSQL 
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_ice_seals_2025.tbl_images")
# RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_ice_seals_2025.geo_images_meta")

# Create list of camera folders within which data need to be processed 
dir <- list.dirs(wd, full.names = FALSE, recursive = FALSE)
dir <- data.frame(path = dir[grep("fl[0-9][0-9][0-9]", dir)], stringsAsFactors = FALSE)
camera_models <- list.dirs(paste(wd, dir$path[1], sep = "/"), full.names = TRUE, recursive = FALSE)
for (i in 2:nrow(dir)){
  temp <- list.dirs(paste(wd, dir$path[i], sep = "/"), full.names = TRUE, recursive = FALSE)
  camera_models <- append(camera_models, temp)
}

camera_models <- camera_models[!grepl("default", camera_models)]
camera_models <- camera_models[!grepl("detections", camera_models)]
camera_models <- camera_models[!grepl("ins_raw", camera_models)]
camera_models <- camera_models[!grepl("processed_results", camera_models)]
camera_models <- camera_models[!grepl("detection_shapefiles", camera_models)]
camera_models <- camera_models[!grepl("fov_shapefiles", camera_models)]

camera_models <- unique(camera_models)
image_dir <- merge(camera_models, c("left_view", "center_view", "right_view"), ALL = true)
colnames(image_dir) <- c("path", "camera_loc")
image_dir$path <- as.character(image_dir$path)
image_dir$camera_dir <- paste(image_dir$path, image_dir$camera_loc, sep = "/")


# Process images and meta.json files by flight to the DB
for (i in 141:nrow(image_dir)){
  # Create image table
  images2DB <- data.frame(image_name = as.character(""), dt = as.character(""), image_type = as.character(""), 
                          image_dir = as.character(""), stringsAsFactors = FALSE)
  images2DB <- images2DB[which(images2DB == "test"), ]
  
  # Create meta.json table
  meta2DB <- data.frame(rjson::fromJSON(file = metaTemplate))
  names(meta2DB)[names(meta2DB) == "effort"] <- "effort_field"
  meta2DB$effort_reconciled <- ""
  meta2DB$meta_file <- ""
  meta2DB$dt <- ""
  meta2DB$flight <- ""
  meta2DB$camera_view <- ""
  meta2DB$camera_model <- ""
  meta2DB <- meta2DB[which(meta2DB == "test"), ]
  
  # Process data
  if(image_dir$path[i] == '//akc0ss-n086/NMML_Polar_Imagery_4/Surveys_IceSeals_2025/fl109_afterBreakerTrip/images_30deg_N56RF') next 
  if(image_dir$path[i] == '//akc0ss-n086/NMML_Polar_Imagery_4/Surveys_IceSeals_2025/fl132_adfg/images_30deg_N56RF') next 
  print(i)
  files <- list.files(image_dir$camera_dir[i], full.names = FALSE, recursive = FALSE)
  files <- data.frame(image_name = files[which(startsWith(files, projectPrefix) == TRUE)], stringsAsFactors = FALSE)
  files$dt <- str_extract(files$image_name, "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9]")
  files$image_type <- ifelse(grepl("rgb", files$image_name) == TRUE, "rgb_image", 
                             ifelse(grepl("ir", files$image_name) == TRUE, "ir_image",
                                    ifelse(grepl("uv", files$image_name) == TRUE, "uv_image", 
                                           ifelse(grepl("meta", files$image_name) == TRUE, "meta.json", "Unknown"))))
  files$image_dir <- image_dir$camera_dir[i]
  
  images <- files[which(grepl("image", files$image_type)), ]
  images2DB <- rbind(images2DB, images)
  
  meta <- files[which(files$image_type == "meta.json"), ]
  if (nrow(meta) > 1) {
    for (j in 1:nrow(meta)){
      meta_file <- paste(image_dir$camera_dir[i], meta$image_name[j], sep = "/")
      metaJ <- data.frame(rjson::fromJSON(file = meta_file))
      names(metaJ)[names(metaJ) == "effort"] <- "effort_field"
      metaJ$effort_reconciled <- NA
      metaJ$meta_file <- basename(meta_file)
      metaJ$dt <- str_extract(metaJ$meta_file, "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9]")
      metaJ$flight <- str_extract(metaJ$meta_file, "fl[0-9][0-9][0-9]")
      metaJ$camera_view <- gsub("_", "", str_extract(metaJ$meta_file, "_[A-Z]_"))
      metaJ$camera_model <- basename(image_dir$path[i])
      meta2DB <- plyr::rbind.fill(meta2DB, metaJ)
    }
  }
  
  colnames(meta2DB) <- gsub("\\.", "_", colnames(meta2DB))
  
  images2DB$flight <- str_extract(images2DB$image_name, "fl[0-9][0-9][0-9]")
  images2DB$camera_view <- gsub("_", "", str_extract(images2DB$image_name, "_[A-Z]_"))
  images2DB$ir_nuc <- NA
  images2DB$rgb_manualreview <- NA
  images2DB$ml_imagestatus <- NA
  
  # Create list of data to process
  df <- list(images2DB, meta2DB)
  dat <- c("tbl_images", "geo_images_meta")
  
  # Import to DB
  for (k in 1:length(dat)){
    RPostgreSQL::dbWriteTable(con, c("surv_ice_seals_2025", dat[k]), data.frame(df[k]), append = TRUE, row.names = FALSE)
    if (k == 2) {
      if (i == 1) {
        sql1 <- paste("ALTER TABLE surv_ice_seals_2025.", dat[k], " ADD COLUMN geom geometry(POINT, 4326)", sep = "")
        RPostgreSQL::dbSendQuery(con, sql1)
      }
      sql2 <- paste("UPDATE surv_ice_seals_2025.", dat[k], " SET geom = ST_SetSRID(ST_MakePoint(ins_longitude, ins_latitude), 4326)", sep = "")
      RPostgreSQL::dbSendQuery(con, sql2)
    }
  }
}

# Disconnect for database and delete unnecessary variables ----------------------------
RPostgreSQL::dbDisconnect(con)
rm(con)