predict_trip_starts <- function(station_id, lag_one_hour, lag_three_hour_median){
  
  df <- matrix(0, nrow = 1, ncol = 46) %>% as.data.frame() %>% as_tibble()
  colnames(df) <- c("station_id", "lag_one_hour", "lag_three_hour_median",
                    paste0("Month_", 1:12), paste0("Hour_", 0:23), paste0("Weekday_", 1:7))
  
  df$station_id <- as.integer(station_id) #72
  df$lag_one_hour <- lag_one_hour
  df$lag_three_hour_median <- 5 #lag_three_hour_median
  df[1, paste0("Month_", month)] <- 1
  df[1, paste0("Hour_", hour)] <- 1
  df[1, paste0("Weekday_", weekday)] <- 1
  
  pred <- ceiling(predict(xgb_trip_starts, as.matrix(df)))
  return(pred)
}

# need a prep data function for intake into predict_trip_starts()
