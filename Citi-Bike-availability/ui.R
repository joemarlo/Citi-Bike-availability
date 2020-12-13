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
  
  # render UI from server - UI determined by if user is mobile or not
  uiOutput("UI")
)
