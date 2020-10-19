
server <- function(input, output, session) {
  
  
  # When map is clicked, show a popup with city info
  observe({
    
    event <- input$map_marker_click
    if (is.null(event)){
      event <- list(id = 3367)
    }
    
    isolate({
      output$marker_text <- renderText(paste0("<h3>Status of station: ", lat_long_df$name[lat_long_df$station_id == event$id], "</h3>"))
      
      # output$table_station_status <-  renderTable(
      #   # return table of current station status
      #   station_status %>% 
      #     filter(station_id == event$id) %>% 
      #     select(station_status, num_bikes_available, is_renting, is_returning) %>% 
      #     t(),
      #   rownames = TRUE
      # )
      
      output$plot_station <- renderPlot(
        station_status %>% 
          filter(station_id == event$id) %>% 
          mutate(Trip_start_prediction = predict_trip_starts(
            station_id,
            last_24 %>% 
              filter(station_id == event$id) %>% 
              arrange(desc(datetime)) %>% 
              mutate(bike_delta = num_bikes_available - lead(num_bikes_available)) %>% 
              head(n = 1) %>%
              pull(bike_delta)
          )) %>% 
          select("Bikes currently available" = num_bikes_available, 
                 'Prediction of trips starting in next hour' = Trip_start_prediction) %>% 
          pivot_longer(cols = everything()) %>% 
          ggplot(aes(x = name, y = value)) +
          geom_col() +
          scale_y_continuous(labels = scales::comma_format(accuracy = 1)) +
          labs(title = "Summary stats for this station",
               x = NULL,
               y = NULL)
      )
      
      output$plot_historical <- renderPlot(
        last_24 %>% 
          filter(station_id == event$id) %>% 
          rename('Bikes available' = num_bikes_available,
                 'Docks available' = num_docks_available) %>% 
          pivot_longer(cols = c("Bikes available", "Docks available")) %>% 
          ggplot(aes(x = datetime, y = value, group = name, color = name)) +
          geom_line() +
          geom_point() +
          scale_y_continuous(labels = scales::comma_format(accuracy = 1)) +
          labs(title = "Historical and projected for this station",
               x = NULL,
               y = NULL,
               color = NULL) +
          theme(legend.position = 'bottom')
      )
      
    })
  })
  
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(noWrap = TRUE)
      ) %>%
      addMarkers(lng = lat_long_df$long, lat = lat_long_df$lat, layerId = lat_long_df$station_id)
  })
}