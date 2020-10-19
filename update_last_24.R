# this script is part of a cron job executed every 15 minutes
library(tidyverse)
Sys.setenv(TZ = 'America/New_York')

# read current file in from dropbox server
old_data <- read_csv(
  "https://www.dropbox.com/s/pt7i2q0wxqwuctf/last_24.csv?dl=1",
  col_types = cols(
    station_id = col_character(),
    station_status = col_character(),
    num_bikes_available = col_double(),
    num_docks_available = col_double(),
    datetime = col_datetime(format = ""),
    Hour = col_double()
  ),
  locale = locale(tz = "America/New_York")
)

# read in latest json 
latest_json <- jsonlite::read_json("http://gbfs.citibikenyc.com/gbfs/gbfs.json")

# read in station status
station_status <- jsonlite::read_json(latest_json$data$en$feeds[[3]]$url)
datetime <- lubridate::as_datetime(station_status$last_updated, tz = Sys.timezone())
station_status <- bind_rows(station_status$data$stations)

# latest data
data_to_append <- station_status %>% 
  select(station_id, station_status, num_bikes_available, num_docks_available) %>% 
  distinct() %>% 
  mutate(datetime = datetime,
         Hour = lubridate::hour(datetime))

# combine, delete old observations, and write out
old_data %>% 
  bind_rows(data_to_append) %>%  
  distinct() %>% 
  filter(datetime >= Sys.time() - as.difftime(6, unit = 'hours')) %>% 
  write_csv("~/Dropbox/Data/Projects/Citi-Bike-availability/last_24.csv")

rm(data_to_append, latest_json, old_data, station_status, datetime)
