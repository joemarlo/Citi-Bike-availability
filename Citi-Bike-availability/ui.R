ui <- fluidPage(
  
  # load custom CSS file
  includeCSS("www/custom_css.css"),
  
  # download roboto font
  HTML('<link rel="stylesheet" href="//fonts.googleapis.com/css?family=Roboto:400,300,700,400italic">'),
  
  titlePanel("Citi Bike availability"),
  
  fluidRow(
    column(6,
           leafletOutput("map", width = "100%", height = "700px"),
           absolutePanel(id = "controls", class = "panel panel-default", fixed = FALSE,
                         draggable = FALSE, top = 10, left = 70, right = "auto", bottom = "auto",
                         width = 200, height = "auto",
                         
                         # h4("Station status"),
                         radioButtons(inputId = "color", 
                                      label = h4("Status station"), 
                                      choices = c("Health (ratio of bikes to docks)", "Bikes available", "Docks available"))),
    ),
    column(6,
           htmlOutput("marker_text"),
           plotlyOutput('plot_historical', height = "580px"),
           HTML('<br><p style="font-size: 0.8em; font-style: italic">This tool is still in draft. It does not currently account for bikes arriving at the station or station dock maximum.')
    )
  ))
