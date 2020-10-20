ui <- fluidPage(
  titlePanel("Current and projected Citi Bike availability"),
  
  fluidRow(
    column(6,
           leafletOutput("map", width = "100%", height = "700px")
    ),
    column(6,
           htmlOutput("marker_text"),
           br(),
           # tableOutput('table_station_status'),
           # plotOutput('plot_station', height = "350px"),
           plotOutput('plot_historical', height = "580px"),
           HTML('<br><p style="font-size: 0.8em; font-style: italic">This tool is still in draft. It does not current account for bikes arriving at the station.')
    )
  ))
