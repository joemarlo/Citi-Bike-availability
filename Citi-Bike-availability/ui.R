ui <- fluidPage(
  titlePanel("Current and projected Citi Bike availability"),
  
  fluidRow(
    column(6,
           leafletOutput("map", width = "100%", height = "800px")
    ),
    column(6,
           htmlOutput("marker_text"),
           # tableOutput('table_station_status'),
           plotOutput('plot_station', height = "350px"),
           plotOutput('plot_historical', height = "350px")
    )
  ))
