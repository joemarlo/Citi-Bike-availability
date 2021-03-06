
server <- function(input, output, session) {

  # if user is on mobile, then display stacked UI, else display overlaid UI
  output$UI <- renderUI({
    
    if (isTRUE(input$is_mobile_device)){

      tagList(
            radioGroupButtons(inputId = "color", label = h3("Station status"), direction = 'vertical', justified = TRUE,
                              checkIcon = list(yes = icon("ok", lib = "glyphicon")), choices = c("Overall health" = 'Health', "Bikes available" = "Bikes", "Docks available" = "Docks")),
            radioGroupButtons(inputId = "timeframe", label = h3("Timeframe"), direction = 'vertical', justified = TRUE,
                              checkIcon = list(yes = icon("ok", lib = "glyphicon")), choices = c("Now", "In one hour")),
            htmlOutput("plot_title"), plotlyOutput('plot_historical', height = "380px"),
       absolutePanel(id = 'legend', class = 'panel panel-default', fixed = FALSE, width = '75px', height = 'auto',
                     draggable = FALSE, top = 75, left = '25', right = 'auto', bottom = 'auto',
                     plotOutput("plot_legend", height = "150px")))

    } else {

      tagList(
        absolutePanel(id = "controls", class = "panel panel-default", fixed = FALSE, width = "40%", height = "auto",
                      draggable = FALSE, top = 80, left = 'auto', right = 50, bottom = "auto",
                      fluidRow(
                        column(6,
                          radioGroupButtons(inputId = "color", label = h3("Station status"), direction = 'vertical', justified = TRUE, 
                                            checkIcon = list(yes = icon("ok", lib = "glyphicon")), choices = c("Overall health" = 'Health', "Bikes available" = "Bikes", "Docks available" = "Docks"))),
                        column(6,
                          radioGroupButtons(inputId = "timeframe", label = h3("Timeframe"), direction = 'vertical', justified = TRUE, 
                                            checkIcon = list(yes = icon("ok", lib = "glyphicon")), choices = c("Now", "In one hour")))), br(),
                      htmlOutput("plot_title"), plotlyOutput('plot_historical', height = "380px"),
        ),
        absolutePanel(id = 'legend', class = 'panel panel-default', fixed = FALSE, width = '75px', height = 'auto',
                      draggable = FALSE, top = 75, left = '25', right = 'auto', bottom = 'auto', plotOutput("plot_legend", height = "150px")))
      }
  })
  
  # get current highlighted marker and set default
  current_marker <- reactive({
    event <- input$map_marker_click
    if (is.null(event)){event <- list(id = default_station)}
    return(event)
  })

  # when station is selected on map, render the plot 
  observe({
    
    selected_station_id <- as.character(current_marker()$id)

    # head info
    output$plot_title <- renderText(paste0("<h3>", lat_long_df$name[lat_long_df$station_id == selected_station_id], "</h3>"))
    
    # plot
    output$plot_historical <- renderPlotly({

      # get the data and add predictions
      station_data <- conn %>% 
        tbl("last_12")  %>%
        filter(station_id == selected_station_id) %>% 
        collect() %>% 
        mutate(datetime = lubridate::as_datetime(datetime, tz = 'America/New_York'))

      # stop here if issue with the data - most likely caused by the SQL table being updated
      validate(need(nrow(station_data) > 0, "Data is currently updating. Try again in 30 seconds."))
        
      # build plot data first so we can separate line types later
      p <- station_data %>%
        rename('Bikes available' = num_bikes_available,
               'Docks available' = num_docks_available) %>%
        pivot_longer(cols = c("Bikes available", "Docks available")) %>% 
        ggplot(aes(x = datetime, y = value, group = name, color = name)) +
        geom_line()
        
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
                     datetime - as.difftime(timediff_vline - 1, unit = 'hours')}) +
        geom_line() +
        geom_point(size = 1) +
        geom_line(data = p_data[p_data$x > datetime - as.difftime(1, unit = 'hours'), ],
                  linetype = "dashed") +
        geom_point(data = p_data[p_data$x > datetime - as.difftime(1, unit = 'hours'), ]) +
        scale_x_datetime(date_breaks = "1 hour", date_labels = "%I:%M %p") +
        scale_y_continuous(labels = scales::comma_format(accuracy = 1)) +
        scale_color_manual(labels = c("Bikes available", "Docks available"), values = c('#c51f5d', '#243447')) +
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
  
  # get current bikes available for each station
  current_bikes_available <- reactive({
    
    # get latest date
    datetime <- conn %>%
      tbl("last_12") %>%
      summarize(max(datetime)) %>%
      collect() %>% 
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
      mutate(health = num_bikes_available / (num_bikes_available + num_docks_available)) %>% 
      collect()
    
    # sort them so order matches lat_long_df
    df <- df[match(lat_long_df$station_id, df$station_id),]
    
    return(df)
  })
  
  # determine circle colors and render color legend based on user input
  circle_colors <- reactive({
    
    input_color <- input$color
    if (is.null(input_color)){input_color <- list(color = "Health")}
    
    if (input_color == "Health"){
      # return diverging viridis colors
      colors_input <- c("#440154FF", "#39568CFF", "#1F968BFF", "#95D840FF", "#1F968BFF", "#39568CFF", "#440154FF")
      pal <- colorNumeric(palette = colors_input, domain = c(0, 1), na.color = "#636363")      
      colors <- pal(current_bikes_available()$health)
      
      # plot legend
      p <- ggplot(tibble(x = 1, y = 1:7), aes(x = x, y = y)) + 
        geom_tile(fill = colors_input) +
        annotate("text", label = "No docks", x = 1, y = 1, color = 'white', fontface = 'bold') +
        annotate("text", label = "Balanced", x = 1, y = 4, color = 'white', fontface = 'bold') +
        annotate("text", label = "No bikes", x = 1, y = 7, color = 'white', fontface = 'bold') +
        theme_void()
      
    } else if (input_color == "Bikes"){
      # return viridis colors bucketed by 0, 1, 2, 3+ bikes available
      colors_input <- c("#440154FF", "#39568CFF", "#1F968BFF", "#95D840FF")
      pal <- colorNumeric(palette = colors_input, domain = c(0, 3), na.color = "#95D840FF")      
      colors <- pal(current_bikes_available()$num_bikes_available)

      # plot legend
      p <- ggplot(tibble(x = 1, y = 1:4), aes(x = x, y = y)) + 
        geom_tile(fill = colors_input) +
        annotate("text", label = "No bikes", x = 1, y = 1, color = 'white', fontface = 'bold') +
        annotate("text", label = "1 bike", x = 1, y = 2, color = 'white', fontface = 'bold') +
        annotate("text", label = "2", x = 1, y = 3, color = 'white', fontface = 'bold') +
        annotate("text", label = "3+", x = 1, y = 4, color = 'white', fontface = 'bold') +
        theme_void()
      
    } else if (input_color == 'Docks'){
      # return viridis colors bucketed by 0, 1, 2, 3+ docks available
      colors_input <- c("#440154FF", "#39568CFF", "#1F968BFF", "#95D840FF")
      pal <- colorNumeric(palette = colors_input, domain = c(0, 3), na.color = "#95D840FF")      
      colors <- pal(current_bikes_available()$num_docks_available)
      
      # plot legend
      p <- ggplot(tibble(x = 1, y = 1:4), aes(x = x, y = y)) + 
        geom_tile(fill = colors_input) +
        annotate("text", label = "No docks", x = 1, y = 1, color = 'white', fontface = 'bold') +
        annotate("text", label = "1 dock", x = 1, y = 2, color = 'white', fontface = 'bold') +
        annotate("text", label = "2", x = 1, y = 3, color = 'white', fontface = 'bold') +
        annotate("text", label = "3+", x = 1, y = 4, color = 'white', fontface = 'bold') +
        theme_void()
      
    } else stop("Invalid selection for station status")
    
    # plot legend
    output$plot_legend <- renderPlot(p)
    
    return(colors)
    })
  
  # build the base map
  output$map <- renderLeaflet(base_map)
  
  # edit the map
  observe({
    leafletProxy("map", session) %>%
      addCircleMarkers(
        lng = lat_long_df$long, lat = lat_long_df$lat,
        layerId = lat_long_df$station_id, group = "station_circles",
        radius = 8, stroke = FALSE, fillOpacity = 0.8, color = circle_colors(),
        popup = lat_long_df$name, popupOptions = c('closeButton' = FALSE)
      )
  })
}