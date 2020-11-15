# this script is part of a cron job executed every 15 minutes
library(tidyverse)
library(pool)
library(xgboost)
setwd('~/Dropbox/Data/Projects/Citi-Bike-availability')
source("creds_master.R")
source("Citi-Bike-availability/R/functions.R")
Sys.setenv(TZ = 'America/New_York')

# read in old data from server
old_data <- conn %>% 
  tbl("last_12") %>% 
  filter(is_pred == 0) %>%
  collect() %>% 
  mutate(datetime = lubridate::as_datetime(datetime, tz = 'America/New_York'))
  
# read in latest json 
latest_json <- jsonlite::read_json("http://gbfs.citibikenyc.com/gbfs/gbfs.json")

# read in station status
station_status <- jsonlite::read_json(latest_json$data$en$feeds[[3]]$url)
datetime <- lubridate::as_datetime(station_status$last_updated, tz = Sys.timezone())
station_status <- bind_rows(station_status$data$stations)

# latest data
data_to_append <- station_status %>% 
  select(station_id, num_bikes_available, num_docks_available) %>% 
  distinct() %>% 
  mutate(datetime = datetime)

# combine, delete old observations, and write out
new_data <- old_data %>% 
  bind_rows(data_to_append) %>%  
  distinct() %>% 
  filter(datetime >= Sys.time() - as.difftime(12, unit = 'hours')) %>% 
  mutate(is_pred = 0)

# TODO add predictions
# load xgb model
#setwd("Citi-Bike-availability")
xgb_trip_starts <- xgboost::xgb.load("Modeling/xgb_trip_starts_R.model")
#setwd("..")

# split df by station
stations_df <- new_data %>% 
  group_by(station_id) %>% 
  group_split()

# add predictions
preds <- map_dfr(stations_df, function(df){
  add_preds(data = df, id = df$station_id[[1]], n_prediction_periods = 3)
}) %>% 
  dplyr::select(station_id, num_bikes_available, num_docks_available, datetime, is_pred) %>% 
  mutate(is_pred = as.numeric(is_pred))

# write out to the database
dbWriteTable(
  conn = conn,
  name = 'last_12',
  value = preds,
  overwrite = TRUE,
  row.names = FALSE
)

# close the connection
DBI::dbDisconnect(conn)
