library(shiny)
library(leaflet)
library(tidyverse)
library(xgboost)
library(zoo)
Sys.setenv(TZ = 'America/New_York')


# data --------------------------------------------------------------------

# read in latest json 
snapshot <- jsonlite::read_json("http://gbfs.citibikenyc.com/gbfs/gbfs.json")

# read in station info
station_details <- jsonlite::read_json(snapshot$data$en$feeds[[2]]$url)

# make lat long table
lat_long_df <- map_dfr(station_details$data$stations, function(tbl){
  tibble(station_id = tbl$station_id, lat = tbl$lat, long = tbl$lon, name = tbl$name)
}) 

# station status
station_status <- jsonlite::read_json(snapshot$data$en$feeds[[3]]$url)
datetime <- lubridate::as_datetime(station_status$last_updated, tz = Sys.timezone())
month <- lubridate::month(datetime)
hour <- lubridate::hour(datetime)
weekday <- lubridate::wday(datetime)
station_status <- bind_rows(station_status$data$stations)

# read in last 12 hours of data
last_24 <- read_csv(
  "https://www.dropbox.com/s/pt7i2q0wxqwuctf/last_24.csv?dl=1",
  col_types = cols(
    station_id = col_character(),
    num_bikes_available = col_double(),
    num_docks_available = col_double(),
    datetime = col_datetime(format = "")
  ),
  locale = locale(tz = "America/New_York")
)


# modeling ----------------------------------------------------------------

# load xgb model
load("Data/xgb_trip_starts.RData")


# other -------------------------------------------------------------------

default_station <- 3367

# map ---------------------------------------------------------------------

# create base map
base_map <- leaflet() %>%
  addProviderTiles(providers$Esri.WorldGrayCanvas,
                   options = providerTileOptions(noWrap = TRUE)) %>% 
  setView(lng = lat_long_df$long[lat_long_df$station_id == default_station],
          lat = lat_long_df$lat[lat_long_df$station_id == default_station],
          zoom = 14)


