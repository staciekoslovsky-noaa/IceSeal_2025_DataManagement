# Process Ice Seals 2025 to create image lists for manual RGB review

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "\\\\akc0ss-n086\\NMML_Polar\\Data\\Annotations\\ice_seals_2025_202603_manualReviewRGB\\"


# Set up working environment
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Reset ML image status field
RPostgreSQL::dbSendQuery(con, "UPDATE surv_ice_seals_2025.tbl_images SET rgb_manualreview = NULL")

# Identify manual review images

# Data collected ON_SAMPLE effort
# This applies to Twin Otter flights starting at fl109
RPostgreSQL::dbSendQuery(con, "UPDATE surv_ice_seals_2025.tbl_images
                              SET rgb_manualreview = 'Y' 
                              WHERE ((flight < 'fl200' AND flight > 'fl108'))
                              AND image_name IN (SELECT image_name FROM surv_ice_seals_2025.geo_images_footprint 
                                                  WHERE fate = 'collected_via_nth' AND effort = 'ON_SAMPLE')")

# Data collected ON_ALL effort 
# This applies to Twin Otter flights fl107 and fl108 and all King Air flights                
images_on_all <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM surv_ice_seals_2025.summ_data_inventory
                                            WHERE (flight = 'fl107' OR flight = 'fl108' OR flight > 'fl200')
                                            AND rgb_image = 'Y'
                                            AND ir_image = 'Y'
                                            AND ir_nuc = 'N'
                                            AND effort_field LIKE 'ON%'")

images_on_all_sampled <- images_on_all %>%
  arrange(flight, camera_view, dt) %>%
  filter(row_number() %% 20 == 0) %>%
  mutate(rgb_manualreview = 'Y')

RPostgreSQL::dbWriteTable(con, c("surv_ice_seals_2025", "temp"), images_on_all_sampled, append = TRUE, row.names = FALSE)

RPostgreSQL::dbSendQuery(con, "UPDATE surv_ice_seals_2025.tbl_images i
                            SET rgb_manualreview = t.rgb_manualreview 
                            FROM surv_ice_seals_2025.temp t
                            WHERE i.flight = t.flight
                            AND i.camera_view = t.camera_view
                            AND i.dt = t.dt")

RPostgreSQL::dbSendQuery(con, "DROP TABLE IF EXISTS surv_ice_seals_2025.temp")

RPostgreSQL::dbSendQuery(con, "UPDATE surv_ice_seals_2025.tbl_images
                              SET rgb_manualreview = 'N' 
                              WHERE rgb_manualreview IS NULL")

# Get manual review images and prepare for export
images <- RPostgreSQL::dbGetQuery(con, "SELECT image_dir || \'\\\' || image_name AS image_path, image_name, flight, camera_view, aircraft, rgb_manualreview , image_type
                                          FROM surv_ice_seals_2025.tbl_images 
                                          WHERE rgb_manualreview = 'Y' 
                                          AND image_type = 'rgb_image'") 

images_ka_c <- images %>%
  filter(aircraft == "kingAir" & camera_view == "C") %>%
  select(image_path) %>%
  arrange(image_path)

images_ka_l <- images %>%
  filter(aircraft == "kingAir" & camera_view == 'L')%>%
  select(image_path) %>%
  arrange(image_path)

images_ka_r <- images %>%
  filter(aircraft == "kingAir" & camera_view == 'R') %>%
  select(image_path) %>%
  arrange(image_path)

images_to_c <- images %>%
  filter(aircraft == "twinOtter" & camera_view == 'C') %>%
  select(image_path) %>%
  arrange(image_path)

images_to_l <- images %>%
  filter(aircraft == "twinOtter" & camera_view == 'L') %>%
  select(image_path) %>%
  arrange(image_path)

images_to_r <- images %>%
  filter(aircraft == "twinOtter" & camera_view == 'R') %>%
  select(image_path) %>%
  arrange(image_path)


# Export data to LAN
setwd(wd)
write.table(images_ka_c, "ice_seals_2025_rgbManualReview_kingAir_C_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(images_ka_l, "ice_seals_2025_rgbManualReview_kingAir_L_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(images_ka_r, "ice_seals_2025_rgbManualReview_kingAir_R_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)

write.table(images_to_c, "ice_seals_2025_rgbManualReview_twinOtter_C_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(images_to_l, "ice_seals_2025_rgbManualReview_twinOtter_L_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)
write.table(images_to_r, "ice_seals_2025_rgbManualReview_twinOtter_R_images.txt", quote = FALSE, row.names = FALSE, col.names = FALSE)

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)