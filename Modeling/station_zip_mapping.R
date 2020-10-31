library(tidyverse)
setwd("/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability")
source('Citi-Bike-availability/R/ggplot_settings.R')
options(mc.cores = parallel::detectCores())

# read in station info
station_details <- jsonlite::read_json("https://gbfs.citibikenyc.com/gbfs/en/station_information.json")

# make lat long table of stations
lat_long_df <- map_dfr(station_details$data$stations, function(tbl){
  tibble(station_id = tbl$station_id, lat = tbl$lat, long = tbl$lon, name = tbl$name)
}) 


# download zip shapefiles -------------------------------------------------

nyc_geojson <- httr::GET('https://data.beta.nyc/dataset/3bf5fb73-edb5-4b05-bb29-7c95f4a727fc/resource/6df127b1-6d04-4bb7-b983-07402a2c3f90/download/f4129d9aa6dd4281bc98d0f701629b76nyczipcodetabulationareas.geojson')
nyc_zip <- rgdal::readOGR(httr::content(nyc_geojson,'text'), 'OGRGeoJSON', verbose = FALSE)
nyc_zip_df <- broom::tidy(nyc_zip)

# map the shapefiles
ggplot() +
  geom_polygon(data = nyc_zip_df,
               aes(x = long, y = lat, group = group, fill = id),
               color = 'white') +
  coord_quickmap() +
  theme(legend.position = 'none')


# which stations are in which zip -----------------------------------------

# create a df with each row as a PUMA with a nest df of the polygon xy vectors
nested_polys <- nyc_zip_df %>% 
  select(long, lat, id) %>% 
  group_by(id) %>% 
  nest()

# iterate through all the lat longs and check to see if a given lat long falls
# inside each of the PUMA polygons
points_in_poly <- pmap_dfr(.l = list(lat_long_df$long, lat_long_df$lat, lat_long_df$station_id), 
                           .f = function(x, y, station_id){
                             
                             df <- map2_dfr(.x = nested_polys$id, .y = nested_polys$data,
                                            .f = function(ID, poly) {
                                              
                                              result <- sp::point.in.polygon(
                                                point.x = x, point.y = y,
                                                pol.x = poly$long, pol.y = poly$lat
                                              )
                                              
                                              return(tibble(station_id = station_id, 
                                                            zip_id = ID, in_poly = result))
                                            }
                             )
                             df$Long <- x
                             df$Lat <- y
                             return(df)
                           })

# create dataframe of stations with their matching zip
station_zip_mapping <- points_in_poly %>% 
  filter(in_poly == 1) %>% 
  select(station_id,
         zip_id) %>% 
  right_join(lat_long_df, by = 'station_id') %>% 
  replace_na(list(zip_id = '999'))

# map of stations colored by zip
station_zip_mapping %>% 
  ggplot(aes(x = long, y = lat, color = zip_id)) +
  geom_point() +
  coord_quickmap() +
  theme(legend.position = 'none')

# write out
station_zip_mapping %>% 
  write_csv("Citi-Bike-availability/Data/station_details.csv")