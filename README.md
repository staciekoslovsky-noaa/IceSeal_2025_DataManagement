# 2025 Ice Seal Survey Data Management

This repository stores the code associated with managing 2025 ice seal survey data. Code numbered 0+ are intended to be run sequentially as the data are available for processing. Code numbered 99 are stored for longetivity, but are intended to only be run once to address a specific issue or run as needed, depending on the intent of the code.

The Datasheets folder contains the KAMERA-specific datasheets for JoBSS surveys.

The data management processing code is as follows:
* **IceSeals2025_01_Import2DB.R** - code to import data from the network into the DB
* **IceSeals2025_01_ProcessFootprints2DB.R** - code to import footprints (from post-processing) into the DB
* **IceSeals2025_02a_SetFieldTypes.txt** - code to define field types to fields created during import
* **IceSeals2025_02b_AssignImageGroup.txt** - code to assign images to image groups for easier cross-table querying
* **IceSeals2025_02c_CreateDataMgmtViews.txt** - code to create views associated with data management and inventory
* **IceSeals2025_02d_Identify0RGBImages.R** - code to identify and label in the DB RGB frames that were dropped (i.e. 0MB in size)

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.