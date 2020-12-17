library(shiny)
library(shinyWidgets)
library(leaflet)
library(tidyverse)
library(plotly)
library(pool)
Sys.setenv(TZ = 'America/New_York')

# connect to Azure database as read-only
conn <- pool::dbPool(
  drv = RMySQL::MySQL(), 
  host = 'citi-bike-server.mysql.database.azure.com',
  dbname = "citi_bike",
  username = "guest@citi-bike-server",
  password = "guest"
)

# disconnect from server when shiny stops
onStop(function() pool::poolClose(conn))

# read lat long table
lat_long_df <- conn %>% 
  tbl("lat_long") %>% 
  collect()

default_station <- 3367

# create base map
base_map <- leaflet(options = leafletOptions(zoomControl = FALSE)) %>%
  addProviderTiles(providers$CartoDB.Positron, 
                   options = providerTileOptions(noWrap = TRUE, minZoom = 12, maxZoom = 15)) %>% 
  setView(lng = lat_long_df$long[lat_long_df$station_id == default_station],
          lat = lat_long_df$lat[lat_long_df$station_id == default_station],
          zoom = 14) %>% 
  setMaxBounds(lng1 = 1.0001 * min(lat_long_df$long), lat1 = 0.9999 * min(lat_long_df$lat),
               lng2 = 0.9970 * max(lat_long_df$long), lat2 = 1.0001 * max(lat_long_df$lat))
