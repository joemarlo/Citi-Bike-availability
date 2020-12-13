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
  absolutePanel(id = "controls", class = "panel panel-default", fixed = FALSE, width = "40%", height = "auto",
                draggable = FALSE, top = 80, left = 'auto', right = 50, bottom = "auto",
                fluidRow(
                  column(6,
                         radioGroupButtons(
                           inputId = "color", label = h3("Station status"), direction = 'vertical', justified = TRUE, checkIcon = list(yes = icon("ok", lib = "glyphicon")),
                           choices = c("Health (ratio of bikes to docks)" = 'Health', "Bikes available" = "Bikes", "Docks available" = "Docks"))),
                  column(6,
                    sliderTextInput(inputId = "timeframe", label = h3("Timeframe"), choices = list("Now", "In one hour")))), br(), 
                htmlOutput("plot_title"),
                plotlyOutput('plot_historical', height = "410px"),
           ),
  absolutePanel(id = 'legend', class = 'panel panel-default', fixed = FALSE, width = '75px', height = 'auto',
                draggable = FALSE, top = 75, left = '25', right = 'auto', bottom = 'auto',
                plotOutput("plot_legend", height = "150px")),
  HTML('<br><p style="font-size: 0.8em; font-style: italic">This tool is still in draft. It does not currently account for station dock maximum.')
  
)
