predict_trip_starts <- function(station_id, lag_one_hour, lag_three_hour_median, datetime){
  
  df <- matrix(0, nrow = 1, ncol = 46) %>% as.data.frame() %>% as_tibble()
  colnames(df) <- c("station_id", "lag_one_hour", "lag_three_hour_median",
                    paste0("Month_", 1:12), paste0("Hour_", 0:23), paste0("Weekday_", 1:7))
  
  month <- lubridate::month(datetime)
  hour <- lubridate::hour(datetime)
  weekday <- lubridate::wday(datetime)
  
  df$station_id <- as.integer(station_id) #72
  df$lag_one_hour <- lag_one_hour
  df$lag_three_hour_median <- lag_three_hour_median
  df[1, paste0("Month_", month)] <- 1
  df[1, paste0("Hour_", hour)] <- 1
  df[1, paste0("Weekday_", weekday)] <- 1
  
  pred <- ceiling(predict(xgb_trip_starts, as.matrix(df)))
  return(pred)
}

# need a prep data function for intake into predict_trip_starts()

# this does not account for bikes returning
# does not account for station dock size

add_preds <- function(data, id, n_prediction_periods = 3) {
  # function iteratively adds rows to the dataframe by predicting the next outcome
  # rows are added in one hour intervals
  
  # filter dataframe to just the station and calculate current stats
  # ISSUE HERE WITH PREDS for current vs. last hour. Shouldn't need to call predict
  # here + causes performance issues
  df <- data %>% 
    filter(station_id == id) %>% 
    mutate(trips_started = pmax(0, lag(num_bikes_available) - num_bikes_available),
           lag_one_hour = zoo::rollsum(trips_started, 4, align = 'right', fill = NA),
           lag_three_hour_median = ceiling(zoo::rollsum(trips_started, 12, align = 'right', fill = NA) / 3)) %>% 
    mutate(pred_one_hour = lag_one_hour) 
    # rowwise() %>%
    # mutate(pred_one_hour = ifelse(
    #   row_number() == max(row_number()),
    #   predict_trip_starts(station_id, lag_one_hour, lag_three_hour_median, datetime),
    #   NA)) %>%
    # ungroup() %>% 
  
  # set lag for rollsum per i
  window <- c(9, 6, rep(3, max(0, n_prediction_periods - 2)))[1:n_prediction_periods]
  
  # add the new rows
  for (i in 1:n_prediction_periods) {
    df <- df %>%
      bind_rows(
        tibble(
          station_id = first(df$station_id),
          num_bikes_available = max(0, last(df$num_bikes_available) - last(df$pred_one_hour)),
          num_docks_available = last(df$num_docks_available) + last(df$pred_one_hour),
          datetime = last(df$datetime) + as.difftime(1, unit = 'hours'),
          trips_started = NA,
          lag_one_hour = NA,
          lag_three_hour_median = NA,
          pred_one_hour = NA
        )
      ) %>%
      # only modify last row
      mutate(
        trips_started = if_else(
          row_number() == max(row_number()),
          pmax(0, lag(num_bikes_available) - num_bikes_available),
          trips_started
        ),
        lag_one_hour = if_else(
          row_number() == max(row_number()),
          lag(trips_started),
          lag_one_hour
        ),
        lag_three_hour_median = if_else(
          row_number() == max(row_number()),
          ceiling(
            zoo::rollsum(trips_started, window[i], align = 'right', fill = NA) / 3
          ),
          lag_three_hour_median
        )
      ) %>%
      rowwise() %>%
      mutate(pred_one_hour = predict_trip_starts(station_id, lag_one_hour, lag_three_hour_median, datetime)) %>%
      ungroup()
  }
  
  # clean up dataframe
  # max_time <- max(data$datetime)
  # df <- df %>%
  #   select(datetime, station_id, num_bikes_available, num_docks_available) %>%
  #   mutate(bikes_avail_pred = num_bikes_available, docs_avail_pred = num_docks_available)
  # df$num_bikes_available[df$datetime > max_time] <- NA
  # df$num_docks_available[df$datetime > max_time] <- NA
  # df$bikes_avail_pred[df$datetime <= max_time] <- NA
  # df$docs_avail_pred[df$datetime <= max_time] <- NA
  
  df$is_pred <- df$datetime > max(data$datetime)
  
  return(df)
  
}

  