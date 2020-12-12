library(shiny)
library(shinyWidgets)
library(leaflet)
library(tidyverse)
library(xgboost)
library(zoo)
library(plotly)
library(viridis)
Sys.setenv(TZ = 'America/New_York')

# connect to database
conn <- pool::dbPool(
  drv = RMySQL::MySQL(), 
  # host = "citi-bike.cjcvdlibs3rm.us-east-1.rds.amazonaws.com",
  host = 'citi-bike-server.mysql.database.azure.com',
  dbname = "citi_bike",
  # username = "guest",
  username = "guest@citi-bike-server",
  password = "guest"
)

# disconnect from server when shiny stops
onStop(function() {
  pool::poolClose(conn)
})


# data --------------------------------------------------------------------

# read lat long table
lat_long_df <- conn %>% 
  tbl("lat_long") %>% 
  collect()


# other -------------------------------------------------------------------

default_station <- 3367

scale_11 <- function(vec){
  # scale between -1:1 while keeping NAs
  omited_vec <- as.vector(na.omit(vec))
  new_values <- ((omited_vec - min(omited_vec)) / (max(omited_vec) - min(omited_vec))) * 2 - 1
  vec[!is.na(vec)] <- new_values
  return(vec)
}


# map ---------------------------------------------------------------------

# create base map
base_map <- leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron, #Jawg.Light #Stamen.TonerLite CartoDB.Positron
                   options = providerTileOptions(noWrap = TRUE,
                                                 minZoom = 11)) %>% 
  setView(lng = lat_long_df$long[lat_long_df$station_id == default_station],
          lat = lat_long_df$lat[lat_long_df$station_id == default_station],
          zoom = 14) %>% 
  setMaxBounds(lng1 = 1.0001 * min(lat_long_df$long),
               lat1 = 0.9999 * min(lat_long_df$lat),
               lng2 = 0.9999 * max(lat_long_df$long),
               lat2 = 1.0001 * max(lat_long_df$lat))
