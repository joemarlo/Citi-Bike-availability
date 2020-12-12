ui <- fluidPage(
  
  # load custom CSS file
  includeCSS("www/custom_css.css"),
  
  # download roboto font
  HTML('<link rel="stylesheet" href="//fonts.googleapis.com/css?family=Roboto:400,300,700,400italic">'),
  
  # set default slider skin
  chooseSliderSkin(skin = "Flat", color = "#2e4c6e"),
  
  # load javascript to check if mobile
  tags$script(src = "js/check_mobile.js"),
  
  # page title
  titlePanel("Citi Bike availability"),

  # map
  leafletOutput("map", width = "100%", height = "700px"),
  
  # panel on right side
  absolutePanel(id = "controls", class = "panel panel-default", fixed = FALSE,
                draggable = FALSE, top = 80, left = 'auto', right = 50, bottom = "auto",
                width = "40%", height = "auto",
                
                fluidRow(
                  column(6,
                    radioButtons(inputId = "color", label = h3("Station status"),
                                 choices = c("Health (ratio of bikes to docks)", "Bikes available", "Docks available"))),
                  column(6,
                    sliderTextInput(inputId = "timeframe", label = h3("Timeframe"),
                                choices = list("Now", "In one hour")))), 
                  br(), 
                htmlOutput("plot_title"),
                plotlyOutput('plot_historical', height = "430px"),
           ),
  HTML('<br><p style="font-size: 0.8em; font-style: italic">This tool is still in draft. It does not currently account for station dock maximum.')
  
)
