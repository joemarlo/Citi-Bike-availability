
server <- function(input, output, session) {
  
  # get current highlighted marker and set default
  current_marker <- reactive({
    event <- input$map_marker_click
    if (is.null(event)){
      event <- list(id = default_station)
    }
    return(event)
  })
  
  # When map is clicked, show a popup with city info
  observe({
    
    event <- current_marker()
    
    isolate({
      
      # head info
      output$marker_text <- renderText(paste0("<h3>Status of station: ", lat_long_df$name[lat_long_df$station_id == event$id], "</h3>"))
      
      # output$table_station_status <-  renderTable(
      #   # return table of current station status
      #   station_status %>% 
      #     filter(station_id == event$id) %>% 
      #     select(station_status, num_bikes_available, is_renting, is_returning) %>% 
      #     t(),
      #   rownames = TRUE
      # )
      
      # top plot
      output$plot_station <- renderPlot(
        station_status %>% 
          filter(station_id == event$id) %>% 
          mutate(Trip_start_prediction = predict_trip_starts(
            station_id,
            lag_one_hour = last_24 %>% 
              filter(station_id == event$id) %>% 
              arrange(desc(datetime)) %>% 
              mutate(bike_delta = num_bikes_available - lead(num_bikes_available)) %>% 
              head(n = 1) %>%
              pull(bike_delta),
            lag_three_hour_median = 5,
            datetime = datetime
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
      
      # bottom plot
      output$plot_historical <- renderPlot({
        # build plot data first so we can seperate line types later
        p <- last_24 %>% 
          add_preds(id = event$id, n_prediction_periods = 3) %>% 
          rename('Bikes available' = num_bikes_available,
                 'Docks available' = num_docks_available) %>% 
          pivot_longer(cols = c("Bikes available", "Docks available")) %>% 
          ggplot(aes(x = datetime, y = value, group = name, color = name)) +
          geom_line()
        
        # pull out plot data
        p_data <- ggplot_build(p)$data[[1]]
        
        # convert time back to datetime
        p_data$x <- lubridate::as_datetime(p_data$x, tz = 'America/New_York')
        
        # build final plot
        ggplot(p_data[p_data$x <= datetime, ], aes(x=x, y=y, color=as.factor(group), group=group)) +
          geom_line() +
          geom_point() +
          geom_line(data=p_data[p_data$x >= datetime - as.difftime(1, unit = 'hours'), ], linetype="dashed") +
          geom_point(data=p_data[p_data$x >= datetime - as.difftime(1, unit = 'hours'), ]) +
          scale_x_datetime(date_breaks = "1 hour", date_labels = "%I:%M %p") +
          scale_y_continuous(labels = scales::comma_format(accuracy = 1)) +
          scale_color_discrete(labels = c("Bikes available", "Docks available")) +
          labs(title = "Historical and projected for this station",
               x = NULL,
               y = NULL,
               color = NULL) +
          theme(legend.position = 'bottom')
      })
      
    })
  })
  
  # function to highlight color of selected marker
  get_marker_colors <- reactive({
    sapply(lat_long_df$station_id, function(id){
      if_else(id == current_marker()$id,
              "black",
              "lightgray")
    }) %>% as.vector()
  })
  
  # custom icons
  # https://rstudio.github.io/leaflet/markers.html
  icons <- reactive({
    awesomeIcons(
      icon = 'bicycle',
      iconColor = '#f5f5f5',
      library = 'fa',
      markerColor = get_marker_colors()
    )
  })
  
  
  # build the map
  output$map <- renderLeaflet(base_map)
  
  # edit the map
  observeEvent(current_marker(), {
    leafletProxy("map", session) %>%
      addAwesomeMarkers(lng = lat_long_df$long, lat = lat_long_df$lat, 
                        layerId = lat_long_df$station_id, icon = icons())
  })
}