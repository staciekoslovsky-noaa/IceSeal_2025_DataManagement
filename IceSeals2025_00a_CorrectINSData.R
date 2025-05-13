# Ice Seals 2025: Correct meta.json with errors in INS data, particularly heading
# S. Koslovsky

# Set Working Variables
wd <- "//akc0ss-n086/NMML_Polar_Imagery_3/Surveys_IceSeals_2025_TEMP"
metaTemplate <- "//akc0ss-n086/NMML_Polar_Imagery_3/Surveys_IceSeals_2025_TEMP/Template4Import.json"
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
install_pkg("tidyverse")
install_pkg("rjson")
install_pkg("plyr")
install_pkg("stringr")
install_pkg("geosphere")

# Run code -------------------------------------------------------
setwd(wd)

# Create list of camera folders within which data need to be processed 
dir <- list.dirs(wd, full.names = FALSE, recursive = FALSE)
#dir <- data.frame(path = dir[grep("fl", dir)], stringsAsFactors = FALSE)
dir <- data.frame(path = dir[grep("fl207", dir)], stringsAsFactors = FALSE) # for testing
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
#image_dir <- merge(camera_models, c("left_view", "center_view", "right_view"), ALL = true)
image_dir <- merge(camera_models, "center_view", ALL = true) # for testing
colnames(image_dir) <- c("path", "camera_loc")
image_dir$path <- as.character(image_dir$path)
image_dir$camera_dir <- paste(image_dir$path, image_dir$camera_loc, sep = "/")

rm(i, temp, wd)

# Load meta.json files
meta2DB <- data.frame(rjson::fromJSON(file = metaTemplate))
meta2DB <- meta2DB[which(meta2DB == "test"), ]

for (i in 1:nrow(image_dir)){
  print(i)
  meta <- list.files(image_dir$camera_dir[i], pattern = "meta.json", full.names = FALSE, recursive = FALSE)
  meta <- data.frame(image_name = meta[which(startsWith(meta, projectPrefix) == TRUE)], stringsAsFactors = FALSE)
  
  if (nrow(meta) > 1) {
    for (j in 1:nrow(meta)){
      meta_file <- paste(image_dir$camera_dir[i], meta$image_name[j], sep = "/")
      metaJ <- data.frame(rjson::fromJSON(file = meta_file))
      meta2DB <- plyr::rbind.fill(meta2DB, metaJ)
    }
  }
}

save(meta2DB, file = "C:\\smk\\ice_seals_2025_fl207_meta.RData")
load("C:\\smk\\ice_seals_2025_fl207_meta.RData")

meta2DB_corrected <- meta2DB %>%
  mutate(last_lat = lag(ins.latitude),
         last_long = lag(ins.longitude),
         last_seq = lag(evt.header.seq)) %>%
  select(evt.header.seq, last_seq, ins.latitude, ins.longitude, ins.heading, last_long, last_lat) %>%
  mutate(seq_diff = evt.header.seq - last_seq) %>%
  mutate(bearing = 0)

for (i in 2:nrow(meta2DB_corrected)) {
  meta2DB_corrected$bearing[i] <- geosphere::bearing(c(meta2DB_corrected$last_long[i], meta2DB_corrected$last_lat[i]), c(meta2DB_corrected$ins.longitude[i], meta2DB_corrected$ins.latitude[i]))
}

meta2DB_corrected <- meta2DB_corrected %>%
  mutate(bearing_adj = ifelse(seq_diff == 1, bearing, lead(bearing))) %>%
  mutate(bearing_adj = ifelse(is.na(seq_diff), lead(bearing_adj), bearing_adj)) %>%
  mutate(bearing_adj = ifelse(bearing_adj == 180, lag(bearing_adj), bearing_adj))
  
# To Do:
## double-check headings and get them in the right numbering for post-processing
## add code for which variables need to be replaced (of heading, pitch and roll)
## export existing heading, pitch, roll values 
## replace heading, pitch, roll values in files (this means not having to re-write the files; if have to re-write, will need to bring in all the variables)
  
  



# Disconnect for database and delete unnecessary variables ----------------------------
RPostgreSQL::dbDisconnect(con)
rm(con, df, dat, i, sql, sql1, sql2)
