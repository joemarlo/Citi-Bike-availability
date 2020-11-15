library(tidyverse)
library(hms)
library(lubridate)
library(RSQLite)
library(xgboost)
setwd("/home/joemarlo/Dropbox/Data/Projects/NYC-data")
source('Plots/ggplot-theme.R')
options(mc.cores = parallel::detectCores())


# connect to database and read in data to memory --------------------------

# establish the connection to the database
conn <- dbConnect(RSQLite::SQLite(), "NYC.db")

# df of all trips
master_df <- tbl(conn, "citibike.2019") %>% 
  select(Starttime, station_id = Start.station.id) %>% 
  collect()

# count trips by the hour
trip_counts <- master_df %>% 
  mutate(Date = as.Date(as_datetime(Starttime)),
         Month = month(Date),
         Day = day(Date),
         Hour = hour(as_datetime(Starttime))) %>% 
  group_by(station_id, Month, Day, Hour) %>% 
  tally() %>% 
  ungroup() %>% 
  mutate(Date = as.Date(paste0("2019-", Month, "-", Day)),
         Weekday = wday(Date))


# read in zip code mapping ------------------------------------------------

setwd("/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability")
station_zip_mapping <-
  read_csv(
    "Citi-Bike-availability/Data/station_details.csv",
    col_types = cols(
      station_id = col_integer(),
      zip_id = col_integer(),
      lat = col_double(),
      long = col_double(),
      name = col_character()
    )
  )


# data prep ---------------------------------------------------------------

# data prep
# convert implicit NAs to explicit
# add lag of n for each station
# convert times to factors
trip_counts_prepped <- trip_counts %>% 
  complete(station_id, Hour, Date) %>% 
  # head(10000) %>%
  group_by(station_id) %>% 
  arrange(station_id, Date, Hour) %>% 
  mutate(
    lag_one_hour = lag(n, 1),
    lag_two_hour = lag(n, 2),
    lag_three_hour = lag(n, 3)) %>% 
  rowwise() %>% 
  mutate(lag_three_hour_median = as.integer(ceiling(median(c(lag_one_hour, lag_two_hour, lag_three_hour), na.rm = TRUE)))) %>%  
  ungroup() %>% 
  drop_na() %>% 
  select(n, station_id, Month, Hour, Weekday, lag_one_hour, lag_three_hour_median) %>% 
  left_join(station_zip_mapping %>% select(station_id, zip_id)) %>% 
  mutate_at(c("Month", "Hour", "Weekday", "zip_id"), as.factor) %>% 
  select(-station_id)

# sample
train_indices <- sample(1:nrow(trip_counts_prepped), size = 1e6, replace = FALSE)
trip_counts_train <- trip_counts_prepped[train_indices,]
trip_counts_test <- trip_counts_prepped[!(1:nrow(trip_counts_prepped) %in% train_indices),]

# dummy code and split
X <- trip_counts_prepped %>% 
  select(zip_id, Month, Hour, Weekday, lag_one_hour, lag_three_hour_median) %>% 
  fastDummies::dummy_cols(remove_selected_columns = TRUE)
X_train <- X[train_indices,]
X_test <- X[!(1:nrow(X) %in% train_indices),]

# train themodel
xgb <- xgboost::xgboost(data = as.matrix(X_train), # training data as matrix
                        label = trip_counts_train$n,  # outcomes
                        nrounds = 30,  # number of trees to build; keep it small for fast load time
                        objective = "count:poisson", 
                        eta = 0.7,
                        depth = 5,
                        verbose = 1
)

# check preds
preds <- predict(xgb, as.matrix(X_test))
sqrt(mean((preds - trip_counts_test$n)^2))

# save the model
setwd("~/Dropbox/Data/Projects/Citi-Bike-availability/Citi-Bike-availability/Data/")
xgboost::xgb.save(xgb, "xgb_trip_starts_two.model")
setwd("/home/joemarlo/Dropbox/Data/Projects/Citi-Bike-availability")

# check preds by zip
trip_counts_test %>% 
  mutate(pred = preds) %>% 
  ggplot(aes(y = pred, group = zip_id)) +
  geom_boxplot() +
  coord_cartesian(ylim = c(0, 30))
