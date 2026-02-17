# Create ice seal image lists

# Install libraries
library(tidyverse)
library(RPostgreSQL)


# Set variables for processing
flights <- c("fl101", "fl102", "fl103", "fl104", "fl105", "fl106")
wd <- "\\\\akc0ss-n086\\NMML_Polar\\Data\\Annotations\\ice_seals_2025_202509_irImageLists_TwinOtter_fl101-fl106\\"

# Set up working environment
"%notin%" <- Negate("%in%")
setwd(wd)
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Get and export images from DB
camera_view <- c("C", "L", "R")

for (f in 1:length(flights)) {
  flight_f <- flights[f]
  for (c in 1:length(camera_view)) {
    camera_view_c <- camera_view[c]
    
    # For ir images
    # images <- RPostgreSQL::dbGetQuery(con, paste0("SELECT image_dir || \'\\' || image_name 
    #                                           FROM surv_ice_seals_2025.tbl_images
    #                                           WHERE flight = \'", 
    #                                               flight_f,
    #                                               "\' AND camera_view = \'",
    #                                               camera_view_c,
    #                                               "\' AND ir_nuc = \'N\' AND image_type = \'ir_image\'"))
    # 
    # write.table(images, paste(wd, paste("ice_seals_2025", flight_f, camera_view_c, "ir_images.txt", sep = "_"), sep = "/"), 
    #             quote = FALSE, row.names = FALSE, col.names = FALSE)
    
    # For rgb images
    images <- RPostgreSQL::dbGetQuery(con, paste0("SELECT image_dir || \'\\' || image_name 
                                              FROM surv_ice_seals_2025.tbl_images
                                              WHERE flight = \'", 
                                                  flight_f,
                                                  "\' AND camera_view = \'",
                                                  camera_view_c,
                                                  "\' AND ir_nuc = \'N\' AND rgb_imagezero = \'N\' AND image_type = \'rgb_image\'"))
    
    write.table(images, paste(wd, paste("ice_seals_2025", flight_f, camera_view_c, "rgb_images.txt", sep = "_"), sep = "/"), 
                quote = FALSE, row.names = FALSE, col.names = FALSE)
    
  }
}

RPostgreSQL::dbDisconnect(con)