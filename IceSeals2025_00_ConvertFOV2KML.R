# Ice Seals 2025: Process FOV Shapefile to KML and Export
# S. Koslovsky, 22 April 2025

# Set variables
flight_num <- 'fl127'
flight_folder <- 'ice_seals_2025_fl127'
date <- '0511'

# Load packages
install_pkg <- function(x)
{
  if (!require(x,character.only = TRUE))
  {
    install.packages(x,dep=TRUE)
    if(!require(x,character.only = TRUE)) stop("Package not found")
  }
}

install_pkg("sf")
install_pkg("tidyverse")

# Process data
shp <- paste0("C:\\Users\\Stacie.Hardy\\Desktop\\ForFieldTeam\\_ForGoogleDrive\\FOV_shapefiles\\", flight_folder, "\\ice_seals_2025_", flight_num, "_center_rgb.shp")

fov <- sf::st_read(shp) %>%
  st_centroid() %>% 
  arrange(image_file) %>%
  mutate(line_id = 1) %>%
  select(image_file, effort, line_id)

for (i in 2:nrow(fov)) {
  fov$line_id[i] <- ifelse(fov$effort[i] == fov$effort[i-1], fov$line_id[i-1], fov$line_id[i-1] + 1)
}

effort2line <- fov %>%
  st_drop_geometry() %>%
  select(effort, line_id) %>%
  unique()
  
fov2kml <- fov %>%
  group_by(line_id) %>%
  summarize(do_union = FALSE) %>% 
  st_cast("LINESTRING") %>%
  left_join(effort2line, by = "line_id") %>%
  filter(grepl('ON', effort)) 

sf::st_write(obj = fov2kml, dsn = paste0("C:\\Users\\Stacie.Hardy\\Desktop\\ForFieldTeam\\_ForForeflight\\", date, "_", flight_num, "_onEffort.kml"))