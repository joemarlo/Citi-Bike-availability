
server <- function(input, output, session) {
  
  # get current bikes available for each station
  current_bikes_available <- reactive({
    
    # get latest date
    datetime <- conn %>%
        tbl("last_12") %>%
        summarize(max(datetime)) %>%
        pull() %>%
        lubridate::as_datetime(., tz = Sys.timezone())
    
    # decide which timeframe to used based on user slider input
    # timediff <- 4 - match(input$timeframe, list("Now", "In one hour", "Two hours", "Three hours"))
    timediff <- 2 - match(input$timeframe, list("Now", "In one hour", "Two hours", "Three hours"))
    datetime_str <- as.character(datetime - as.difftime(timediff, unit = 'hours'))

    # pull the data corresponding to the user input
    df <- conn %>%
      tbl("last_12") %>%
      filter(datetime == datetime_str) %>% 
      select(station_id, num_bikes_available, num_docks_available) %>%
      mutate(health = pmax(-3, pmin(3, log(num_bikes_available / num_docks_available)))) %>% 
      collect()
    
    # sort them so order matches lat_long_df
    df <- df[order(match(df$station_id,lat_long_df$station_id)),]
    
    return(df)
  })
  
  # get current highlighted marker and set default
  current_marker <- reactive({
    event <- input$map_marker_click
    if (is.null(event)){event <- list(id = default_station)}
    return(event)
  })

  # output$plot_output <- renderPlot({
  #   plot(rnorm(10), rnorm(10))
  # })
  
  # When map is clicked, show a popup with city info
  observe({
    
    selected_station_id <- as.character(current_marker()$id)
    
    isolate({
      
      # head info
      output$marker_text <- renderText(paste0("<h3>", lat_long_df$name[lat_long_df$station_id == selected_station_id], "</h3>"))
      
      # plot
      output$plot_historical <- renderPlotly({

        # get the data and add predictions
        station_data <- conn %>% 
          tbl("last_12")  %>%
          filter(station_id == selected_station_id) %>% 
          collect() %>% 
          mutate(datetime = lubridate::as_datetime(datetime, tz = 'America/New_York'))
        
        # build plot data first so we can seperate line types later
        p <- station_data %>%
          rename('Bikes available' = num_bikes_available,
                 'Docks available' = num_docks_available) %>%
          pivot_longer(cols = c("Bikes available", "Docks available")) %>% 
          ggplot(aes(x = datetime, y = value, group = name, color = name)) +
          geom_line()
        
        # stop here if issue building the base plot (most likely cause by
        #   lack of data)
        validate(need(is.ggplot(p), "Data currently not available"))

        # pull out plot data
        p_data <- ggplot_build(p)$data[[1]]

        # convert time back to datetime
        p_data$x <- lubridate::as_datetime(p_data$x, tz = 'America/New_York')

        # get datetime of last observed data (= 1 + n_prediction_periods)
        # datetime <- sort(station_data$datetime, decreasing = TRUE)[4]
        datetime <- sort(station_data$datetime, decreasing = TRUE)[2]
        
        # build final plot
        p <- ggplot(p_data[p_data$x <= datetime, ],
               aes(x = x, y = y, color = as.factor(group), 
                   group = group, text = paste0(strftime(x, format = "%I:%M %p"), ":  ", y, ' units'))) +
          geom_vline(color = "grey50", alpha = 0.8, linetype = 'dash',
                     # xintercept = {
                     #   timediff_vline <- 4 - match(input$timeframe, list("Now", "In one hour", "Two hours", "Three hours"))
                     #   datetime - as.difftime(timediff_vline - 3, unit = 'hours')
                     # }
                     xintercept = {
                       timediff_vline <- 2 - match(input$timeframe, list("Now", "In one hour"))
                       datetime - as.difftime(timediff_vline - 1, unit = 'hours')
                     }
                     ) +
          geom_line() +
          geom_point() +
          # geom_ribbon(data = p_data[p_data$x >= datetime - as.difftime(10, unit = 'mins'), ],
          #             aes(ymax = y + (1.5 * difftime(x, datetime, units = 'hours')), 
          #                 ymin = y - (1.5 * difftime(x, datetime, units = 'hours'))),
          #             fill = 'grey90', color = 'white', alpha = 0.8) +
          geom_line(data = p_data[p_data$x > datetime - as.difftime(1, unit = 'hours'), ],
                    linetype = "dashed") +
          geom_point(data = p_data[p_data$x > datetime - as.difftime(1, unit = 'hours'), ]) +
          scale_x_datetime(date_breaks = "1 hour", date_labels = "%I:%M %p") +
          scale_y_continuous(labels = scales::comma_format(accuracy = 1)) +
          scale_color_discrete(labels = c("Bikes available", "Docks available")) +
          labs(x = NULL, y = NULL, color = NULL)
        
        # convert to plotly
        fig <- ggplotly(p, dynamicTicks = TRUE, tooltip = c("text")) %>%
          layout(
            legend = list(orientation = "h", xanchor = "center", x = 0.5, y = 1.1),
            xaxis = list(fixedrange = TRUE),
            yaxis = list(fixedrange = TRUE)
          ) %>%
          style(hoverlabel = list(bordercolor = "white")) %>%
          config(displayModeBar = FALSE)

        # rename legend
        fig <- plotly_build(fig)
        fig$x$data[[2]]$name <- "Bikes available"
        fig$x$data[[3]]$name <- "Docks available"

        return(fig)
      })
      
    })
  })
  
  # function to determine circle colors and highlight color of selected marker
  circle_colors <- reactive({
    
    # map user input to data column
    metric <- switch(
      input$color,
      "Health (ratio of bikes to docks)" = scale_11(current_bikes_available()$health), 
      "Bikes available" = scale_11(current_bikes_available()$num_bikes_available), 
      "Docks available" = scale_11(current_bikes_available()$num_docks_available)
    )

    # set colors based on user input
    colors <- colorNumeric(palette = c("#eb6060",'#f7e463', "#7cd992", '#f2e061', "#eb5e5e"), domain = c(-1, 1))(metric)
  
    # replace NAs with red
    colors[is.na(metric)] <- "#eb6060"
  
    # replace selected station with color gray
    # colors[lat_long_df$station_id == current_marker()$id] <- "#2b2b2b"
      
    return(colors)
    })
  
  # html for popup plot
  # popup_plot <- reactive({
  #   popup_html <- rep("", nrow(lat_long_df))
  #   
  #   # replace selected station with div
  #   popup_html[lat_long_df$station_id == current_marker()$id] <-
  #     '<div id="plot_output" class="shiny-plot-output" style="width: 100px; height: 100%"></div>'
  #   
  #   return(popup_html)
  # })
  
  
  # build the base map
  output$map <- renderLeaflet(base_map)
  
  # edit the map
  observe({
    leafletProxy("map", session) %>%
      addCircleMarkers(
        lng = lat_long_df$long, lat = lat_long_df$lat,
        layerId = lat_long_df$station_id, group = "station_circles",
        radius = 8, stroke = FALSE, fillOpacity = 0.8,
        color = circle_colors(),
        popup = lat_long_df$name, popupOptions = c('closeButton' = FALSE)
      )
    # popup = HTML(popup_plot()))
  })
}