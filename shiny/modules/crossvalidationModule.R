#
# Crossvalidation Module
#

#uncomment for testing
#source("packages.R")
#source("loadModule.R")
#source("functions.R")
#config = yaml.load_file("config.yml") #get password information from yml file

#
#USER INTERFACE
#

crossvalidationUI <- function(id) {
  ns <- NS(id)
  
  tagList(
    numericInput(ns("split_percent"), label = "Percentage for testing set from the dataset", min = 10, value = 20, max = 50),
    )
}

#
#SERVER
#

crossvalidationServer <- function(id, data) {
  moduleServer(
    id,
    function(input, output, session) {
      
      split_percent <- (input$split_percent)/100
      
      result.list <- reactive({
        
        data_1 <- data
        
        #CROSSVALIDATION ONE
        tmp <- crossvalidate_data(data_1, split_percent)
        ts_data_1 <- tmp[[1]][[2]][,2]
        df.accuracy_1 <- tmp[[1]][[1]] %>% mutate(Crossvalidation = "3")
        data_2 <- tmp[[2]]
        
        #CROSSVALIDATION TWO
        tmp <- crossvalidate_data(data_2, split_percent)
        ts_data_2 <- tmp[[1]][[2]][,2]
        df.accuracy_2 <- tmp[[1]][[1]] %>% mutate(Crossvalidation = "2")
        data_3 <- tmp[[2]]
        
        #CROSSVALIDATION THREE
        tmp <- crossvalidate_data(data_3, split_percent)
        ts_data_3 <- tmp[[1]][[2]][,2]
        df.accuracy_3 <- tmp[[1]][[1]] %>% mutate(Crossvalidation = "1")
        
        # used later for the visualisation
        data <- prepare_for_prediction(data_1)
        names(data) <- c("Actual")
        
        ####
        #RESULTS ---------------------------------------------------------------------------
        ####
        
        #MERGE ACCURACY
        df_accuracy <- bind_rows(df.accuracy_1, df.accuracy_2, df.accuracy_3)
        
        #MERGE RESULTS
        tmp <- merge(ts_data_1, ts_data_2, all = T)
        tmp <- merge(tmp, ts_data_3, all = T)
        ts_data <- merge(tmp, data, all = T)
        names(ts_data) <- c("Prediction_3","Prediction_2","Prediction_1","Actual")
        
        #save as list
        result.list <- list(ts_data, df_accuracy)
        return(result.list)
        
      })
      
      return(result.list)
      
    })
}

### FOR TESTING

ui <- fluidPage(
  
  fluidRow(
    column(12,
           h3("Crossvalidation Interactive Plot"),
           dygraphOutput("dygraph.cv")
    )
  ),
    
  fluidRow(
    column(4,
           h3("Crossvalidation Configurations"),
           crossvalidationUI("crossvalidationModule")
    ),
    column(8,
           h3("Crossvalidation Training & Testing Accuracy"),
           tableOutput("acc.cv")
    )
  )
  
  )

server <- function(input, output, session) {
  
  #
  # TESTING VARIABLES AREA START -----------------------------------------------
  #
  
  # database configurations
  con <- dbConnect(RPostgres::Postgres(),
                   dbname = 'nyc_data',
                   host = 'localhost',
                   port = 5432,
                   user = 'postgres',
                   password = config$TIMESCALEDB$PW)
  
  # import configurations
  time_config = "60" #choose input for time_bucket_gapfill function from timescaledb in minutes
  index_config = "pickup_datetime" #choose a table that contains the index
  value_config = "COUNT(*)" #choose the function/table that contains the values
  table_config = "rides" #choose table in database
  
  data <- import_data_from_db(con, time_config, index_config, value_config, table_config)
  
  #
  # TESTING VARIABLES END  -----------------------------------------------------
  #
  
  result.list  <- reactive({
    result <- crossvalidationServer("crossvalidationModule", data)
  })
  
  output$dygraph.cv <- renderDygraph({
    results <- result.list()
    ts_data <- results()[[1]]

    #DETERMIN HIGHLIGHTS IN VISUALIZATION
    df_data <- data.frame(ts_data)
    shade_1.start <- df_data[3] %>% na.omit() %>% head(1) %>% row.names()
    shade_2.start <- df_data[2] %>% na.omit() %>% head(1) %>% row.names()
    shade_3.start <- df_data[1] %>% na.omit() %>% head(1) %>% row.names()
    shade_1.end <- df_data[3] %>% na.omit() %>% tail(1) %>% row.names()
    shade_2.end <- df_data[2] %>% na.omit() %>% tail(1) %>% row.names()
    shade_3.end <- df_data[1] %>% na.omit() %>% tail(1) %>% row.names()
    
    dygraph(ts_data) %>% 
      dyRangeSelector() %>% 
      dyOptions(drawPoints = F, pointSize = 2, colors = c("red", "blue","green","black")) %>% 
      dyUnzoom() %>% 
      dyCrosshair(direction = "vertical") %>% 
      dyLegend(width = 400) %>% 
      dyShading(from = shade_1.start, to = shade_1.end, color = "#CCEBD6") %>% 
      dyShading(from = shade_2.start, to = shade_2.end, color = "#CCE5FF") %>% 
      dyShading(from = shade_3.start, to = shade_3.end, color = "#FFE6E6")
    
  })
  
  output$acc.cv <- renderTable({
    results <- result.list()
    df_accuracy <- results()[[2]]
  })
  
}

shinyApp(ui, server)
