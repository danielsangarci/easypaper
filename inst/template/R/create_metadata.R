#How to set up metadata following https://annakrystalli.me/dataspice-tutorial/

# Get the last version of dataspice and load it
#install.packages("devtools")
#devtools::install_github("ropenscilabs/dataspice")

# 1. Load necessary libraries
library(dataspice)
library(jsonlite)   # For reading the JSON
library(magrittr)   # For the pipe operator (%>%)

# ---------------------------------------------------------
# SETUP: Define your paths
# ---------------------------------------------------------
# We define this once so we don't have to keep typing "../data"
data_folder <- "data"
metadata_folder <- "data/metadata" 

# ---------------------------------------------------------
# STEP 2: Create the metadata folders and templates
# ---------------------------------------------------------
# This creates a "metadata" folder inside "../data" and adds 
# 4 empty CSV files (attributes, access, biblio, creators).
create_spice(dir = data_folder)

# ---------------------------------------------------------
# STEP 3: Auto-fill variable names from your 4 datasets
# ---------------------------------------------------------
# Get a list of your 4 CSV files with their full paths
my_files <- list.files(path = data_folder, pattern = "\\.csv$", full.names = TRUE)

# Define where the attributes.csv template is located
attr_template <- file.path(metadata_folder, "attributes.csv")

# Loop through every file and add its variables to the template
for (file in my_files) {
  message(paste("Processing:", file))
  prep_attributes(data_path = file, attributes_path = attr_template)
}

# ---------------------------------------------------------
# STEP 4: Manually fill in the details
# ---------------------------------------------------------
# Run these lines one by one. They will open a pop-up window 
# where you can type in your info. Save when done.

# Add authors/researchers
edit_creators(metadata_dir = metadata_folder)

# Add title, abstract, and temporal coverage
edit_biblio(metadata_dir = metadata_folder)

# Add details about the variables (units, descriptions)
# Note: The variable names are already there because of Step 3!
edit_attributes(metadata_dir = metadata_folder)

# Add URL/access details (optional)
edit_access(metadata_dir = metadata_folder)

# ---------------------------------------------------------
# STEP 5: Save and Compile JSON
# ---------------------------------------------------------
# This converts your CSVs into a single 'dataspice.json' file
# located in "../data/metadata"
write_spice(path = metadata_folder)

# Optional: Inspect the JSON
# We construct the path using the 'metadata_folder' variable 
# to ensure we are looking in "../data/metadata/dataspice.json"
json_file_path <- file.path(metadata_folder, "dataspice.json")

# Read and view interactively
jsonlite::read_json(json_file_path) %>% 
  listviewer::jsonedit()

# ---------------------------------------------------------
# STEP 6: Create a nice README website to view metadata
# ---------------------------------------------------------
# This creates an 'index.html' file you can open in your browser
# to ensure the index.html file is created in the metadata folder
index_file_path <- file.path(metadata_folder, "index_metadata.html")
build_site(path = json_file_path, out_path = index_file_path)


