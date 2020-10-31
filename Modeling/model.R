library(tidyverse)
library(hms)
library(lubridate)
library(RSQLite)
setwd("/home/joemarlo/Dropbox/Data/Projects/NYC-data")
source('Plots/ggplot-theme.R')
options(mc.cores = parallel::detectCores())


# connect to database and read in data to memory --------------------------

# establish the connection to the database
conn <- dbConnect(RSQLite::SQLite(), "NYC.db")

# df of all trips
master_df <- tbl(conn, "citibike.2019") %>% 
      collect()

# count trips by the hour
trip_counts <- master_df %>% 
  select(Starttime, station_id = Start.station.id) %>% 
  mutate(Date = as.Date(as_datetime(Starttime)),
         Month = month(Date),
         Day = day(Date),
         Hour = hour(as_datetime(Starttime))) %>% 
  group_by(station_id, Month, Day, Hour) %>% 
  tally() %>% 
  ungroup() %>% 
  mutate(Date = as.Date(paste0("2019-", Month, "-", Day)),
         Weekday = wday(Date))


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
  mutate_at(c("Month", "Hour", "Weekday"), as.factor)

# sample
train_indices <- sample(1:nrow(trip_counts_prepped), size = 1e6, replace = FALSE)
trip_counts_train <- trip_counts_prepped[train_indices,]
trip_counts_test <- trip_counts_prepped[!(1:nrow(trip_counts_prepped) %in% train_indices),]

trip_counts_train %>% 
  filter(Month == 1,
         Weekday == 2,
         station_id %in% 1:200) %>% 
  ggplot(aes(x = Hour, y = n, group = station_id)) +
  geom_line() +
  facet_wrap(~station_id)


# dummy code and split
X <- trip_counts_prepped %>% 
  select(station_id, Month, Hour, Weekday, lag_one_hour, lag_three_hour_median) %>% 
  fastDummies::dummy_cols(remove_selected_columns = TRUE)
X_train <- X[train_indices,]
X_test <- X[!(1:nrow(X) %in% train_indices),]

# library(xgboost)  
xgb <- xgboost::xgboost(data = as.matrix(X_train), # training data as matrix
                        label = trip_counts_train$n,  # outcomes
                        nrounds = 25,  # number of trees to build; keep it small for fast load time
                        objective = "count:poisson", 
                        # eta = 0.3,
                        depth = 10,
                        verbose = 1
)

# check preds
preds <- predict(xgb, as.matrix(X_test))
sqrt(mean((preds - trip_counts_test$n)^2))

tibble(y = trip_counts_test$n, y_hat = preds) %>% 
  slice_sample(n = 100000) %>% 
  ggplot(aes(x = y_hat, y = y)) +
  geom_point(alpha = 0.03) +
  geom_abline(intercept = 0, slope = 1)

# simulate time series prediction for a few stations
pred_sim <- trip_counts %>% 
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
  mutate_at(c("Month", "Hour", "Weekday"), as.factor) %>% 
  fastDummies::dummy_cols(select_columns = c("Month", "Hour", "Weekday"))

# skimr::skim

pred_sim_1 <- pred_sim %>% 
  filter(Date == as.Date("2019-04-01"),
         station_id %in% 190:250)

pred_sim_1$y_hat <- predict(xgb, as.matrix(pred_sim_1 %>% select(-n, -Date, -Month, -Day, -Hour, -Weekday, -lag_two_hour, -lag_three_hour)))
  
pred_sim_1 %>% 
  select(station_id, Hour, n, y_hat) %>% 
  pivot_longer(cols = c("n", "y_hat")) %>% 
  ggplot(aes(x = Hour, y = value, group = name, color = name)) +
  geom_line() +
  facet_wrap(~station_id)

# data prep 
xgb_trip_starts <- xgb
# save(xgb_trip_starts, file = "~/Desktop/Citi-Bike-traffic/xgb_trip_starts.RData")
setwd("~/Dropbox/Data/Projects/Citi-Bike-availability/Citi-Bike-availability/Data/")
xgboost::xgb.save(xgb, "xgb_trip_starts.model")
setwd("/home/joemarlo/Dropbox/Data/Projects/NYC-data")


predict_trip_starts <- function(station_id){

  # look at recipes https://recipes.tidymodels.org/reference/prep.html
  #https://www.tidymodels.org/start/recipes/
  
  df <- matrix(0, nrow = 1, ncol = 46) %>% as.data.frame() %>% as_tibble()
  colnames(df) <- c("station_id", "lag_one_hour", "lag_three_hour_median",
                    paste0("Month_", 1:12), paste0("Hour_", 0:23), paste0("Weekday_", 1:7))
  
  df$station_id <- as.integer(station_id) #72
  df$lag_one_hour <- 5 
  df$lag_three_hour_median <- 5
  df[1, paste0("Month_", month)] <- 1
  df[1, paste0("Hour_", hour)] <- 1
  df[1, paste0("Weekday_", weekday)] <- 1
  
  pred <- predict(xgb_trip_starts, as.matrix(df))
  return(pred)
}

# glm
trip_counts %>% 
  filter(station_id %in% 190:250) %>% 
  group_by(station_id) %>% 
  nest() %>% 
  mutate(model = map(data, function(df) glm(n ~ Month + Day + Hour + Weekday,
                                            data = df, family = quasipoisson(link = 'log')))) %>% 
  left_join(trip_counts %>% 
              filter(station_id %in% 190:250,
                     Date == as.Date("2019-05-05"))) %>% 
  group_by(station_id) %>% 
  do(modelr::add_predictions(., first(.$model))) %>% 
  select(station_id, Hour, n, pred) %>% 
  pivot_longer(cols = c("n", "pred")) %>% 
  ggplot(aes(x = Hour, y = value, color = name)) +
  geom_line() +
  facet_wrap(~station_id)
  



library(lme4)

mlm <- lme4::glmer(n ~ (Month | station_id) + (Hour | station_id) + (Weekday | station_id), 
                   data = slice_sample(n = 100000, trip_counts_train), family = "poisson",
                   verbose = 2)


library(rstanarm)
mlm_bayes <- rstanarm::stan_glmer(formula = n ~ (Month | station_id) + (Hour | station_id) + (Weekday | station_id), 
                     family = rstanarm::neg_binomial_2, 
                     data = slice_sample(n = 100000, trip_counts_train), 
                     adapt_delta = 0.9, iter = 1000, seed = 44)
