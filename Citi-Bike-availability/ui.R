ui <- fluidPage(
  
  # load custom CSS file
  includeCSS("www/custom_css.css"),
  
  # download roboto font
  HTML('<link rel="stylesheet" href="//fonts.googleapis.com/css?family=Roboto:400,300,700,400italic">'),
  
  # load javascript to check if mobile
  tags$script(src = "js/check_mobile.js"),
  
  # page title
  titlePanel("Citi Bike availability"),
  
  # render the map
  leafletOutput("map", width = "100%", height = "700px"),
  
  # render UI from server - UI determined by if user is mobile or not
  uiOutput("UI"),
  
  # page footer
  HTML('<br><p style="font-size: 0.8em; font-style: italic">Data from Citi Bike. Updated every 15 minutes. Does not include electric bikes. See <a href="https://www.marlo.works/posts/citi-bike-availability/">marlo.works</a> for more info.</p>')
)
