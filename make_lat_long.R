library(tidyverse)
source("creds_master.R")

# read in station info
# station_details <- jsonlite::read_json(snapshot$data$en$feeds[[2]]$url)
station_details <- jsonlite::read_json("https://gbfs.citibikenyc.com/gbfs/en/station_information.json")

# make lat long table
lat_long_df <- map_dfr(station_details$data$stations, function(tbl){
  tibble(station_id = tbl$station_id, lat = tbl$lat, long = tbl$lon, name = tbl$name)
}) 

# write table to DB
DBI::dbWriteTable(conn = conn, name = 'lat_long', value = lat_long_df, overwrite = TRUE, row.names = FALSE)

# close the connection
DBI::dbDisconnect(conn)