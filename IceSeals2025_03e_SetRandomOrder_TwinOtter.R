# Ice Seals 2025: Set random order for species ID and quartile breaks for species misclassification (Twin Otter)

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set up working environment
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Get data from DB
ir_summary <- RPostgreSQL::dbGetQuery(con, "SELECT flight, camera_view, count(flight) as num_animals 
                                      FROM surv_ice_seals_2025.tbl_detections_processed_ir 
                                      WHERE (detection_type = \'animal\' OR detection_type = \'animal_new\' OR detection_type = \'animal_duplicate\') AND flight LIKE \'fl1%\'
                                      GROUP BY flight, camera_view")

# Set random order and update DB
set.seed(129)
ir_summary <- ir_summary[sample(1:nrow(ir_summary)), ]
ir_summary$random_order <- 1:nrow(ir_summary)

# Update random order in DB
for (i in 1:nrow(ir_summary)){
  RPostgreSQL::dbSendQuery(con, paste("UPDATE annotations.tbl_detector_meta ",
                                      "SET random_order = ", ir_summary$random_order[i],
                                      " WHERE project_schema = \'surv_ice_seals_2025\' AND flight = \'", ir_summary$flight[i],
                                      "\' AND camera_view = \'", ir_summary$camera_view[i], "\'", sep = ""))
}

# Identify quartile breaks of data in random order
# ir_summary$cumsum_animals <- cumsum(ir_summary$num_animals)
# ir_summary$proportion_animals <- ir_summary$cumsum_animals / max(ir_summary$cumsum_animals)

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
