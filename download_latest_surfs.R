suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(tidyverse)
  # library(leaflet)
  # library(rlang, quietly = T, )
  library(yaml)
})

# Step 1: Polar
# Get file from polar API

my_config <- read_yaml("SURFING_POLAR/config.yml_SURF")

# create transaction
myf1 = POST(paste0("https://www.polaraccesslink.com/v3/users/", my_config$user_id, "/exercise-transactions"),
            add_headers(Accept = "application/json"),
            add_headers("Content-Type" = "application/json"),
            add_headers(Authorization = paste0("Bearer ", my_config$access_token)))
warn_for_status(myf1)
# exit if it's empty, as there are no activities
if(is_empty(content(myf1))){
  cat("Exiting, no recent activities...\n")
  # quit()
} else {
myd1 = jsonlite::fromJSON(content(myf1, as="text", encoding = "UTF-8"))
# myd1

# list exercises
myf2 = GET(paste0("https://www.polaraccesslink.com/v3/users/", my_config$user_id,
                  "/exercise-transactions/", myd1$`transaction-id`),
           add_headers(Accept = "application/json"),
           add_headers(Authorization = paste0("Bearer ", my_config$access_token)))
warn_for_status(myf2)
myd2 = jsonlite::fromJSON(content(myf2, as="text", encoding = "UTF-8"))
# myd2

# download gpx data, fix, and save
if(length(myd2$exercises) == 1) {
  cat(paste0("Found ", length(myd2$exercises),
             " new activity:\n\n"))
} else {
  cat(paste0("Found ", length(myd2$exercises),
             " new activities:\n\n"))
}

act_n <- 1
for (ex in myd2$exercises) {
  # get info from exercise
  myex1 = GET(ex,
              add_headers(Accept = "application/json"),
              add_headers(Authorization = paste0("Bearer ", my_config$access_token)))
  warn_for_status(myex1)
  myexd1 = jsonlite::fromJSON(content(myex1, as="text", encoding = "UTF-8"))
  # print details
  cat(paste0("Activity ", act_n, ": ",
             myexd1$`detailed-sport-info`,
             ", on ", myexd1$`start-time`,
             "\nProcessing...\n\n"))
  # myexd1
  # check if it's swimming, otherwise, skip
  if(myexd1$`detailed-sport-info` == "WATERSPORTS_SURFING"){
    cat(paste0("Activity ", act_n, " has correct surfing data.\n"))
    # get gpx
    my_gpx = GET(paste0(ex,"/gpx"),
                 add_headers(Accept = "application/gpx+xml"),
                 add_headers(Authorization = paste0("Bearer ", my_config$access_token)))
    warn_for_status(my_gpx)
    my_gpx_data = content(my_gpx, as="text", encoding = "UTF-8")
    my_filename <- here::here("surfs",
                              paste0("surfing_polar_", str_replace_all(myexd1$`start-time`,":","-"), ".gpx"))
    write(my_gpx_data, file=my_filename)
    cat(paste0("Downloaded and saved gpx file: ", my_filename ,"\n\n"))
  } else {
    cat(paste0("Activity ", act_n, " does not have correct surfing data.\nActivity ignored.\n\n"))
  }
  act_n <- act_n + 1
}

# commit transaction and delete data
my_form_commit = PUT(paste0("https://www.polaraccesslink.com/v3/users/", my_config$user_id,
                            "/exercise-transactions/", myd1$`transaction-id`),
                     add_headers(Authorization = paste0("Bearer ", my_config$access_token)))
warn_for_status(my_form_commit)
# my_form_commit
}