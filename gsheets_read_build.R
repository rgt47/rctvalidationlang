library(pacman)
p_load(stringr, googlesheets, readr, dplyr, magrittr, lubridate, knitr)

source("~/projects/reports/templates/zzreports.R")
Sys.setenv(TZ = "America/Los_Angeles")
options(scipen = 1, digits = 2)

ReadAllSheets <- function(fname) {
    sheets <- readxl::excel_sheets(fname)
    x <- lapply(sheets, function(X) readxl::read_excel(fname, sheet = X))
    names(x) <- sheets
    x
}

gs_auth()
dd <- gs_title("edc0_template_dd")
gfname <- gs_download(dd, overwrite = TRUE)

# dl: a list of dfs. one for each sheet in dictionary
dl <- ReadAllSheets(gfname)

# sl: front page of google sheet
sl <- dl[["edc0-data-dictionary"]]
# vl: list of unique visits in trial
vl <- sl$visits %>% str_replace_all(" ", "") %>% strsplit(",") %>% unlist %>% 
    unique



#write file with observeEvent for save for each form
savetxt = paste0("observeEvent(input$submit", sl$workingname[-1], ",{saveData('",sl$workingname[-1],"')})") 
write(savetxt, ".forms/save.R")

#write file with renderUI for  each visit
rendertxt = paste0("output$vis", vl, " <-  renderUI({source('.forms/", vl,
"panel', local=T)[[1]]})") 
write(rendertxt,".forms/renderpanels.R")

#write file with h for hidden panels for each visit
hiddentxt1 = paste0("hidden(uiOutput('vis", vl[-1],"')),")
hiddentxt2 = c("tagList(", hiddentxt1) 
hiddentxt2[length(hiddentxt2)] %<>%  sub(",", ")", .)  
write(hiddentxt2, ".forms/hidden.R")

#add a row count to each element in dl list
dl <- lapply(dl, function(x) {
    cbind(x, cnt = 1:nrow(x))
})

# vf: convert sl$visits (visits per form) to forms per visit
vf <- lapply(vl, function(x) {
    sl$workingname[grepl(x, sl$visits)]
})
names(vf) <- vl

# 
panel0 <- function(vis) {
    dl[vf[[vis]]] %>% 
    do.call("rbind", .)
}

parseCond <- function(x) {
    if (is.na(x)) 
        return(x)
    foo <- strsplit(x, "=")
    foo2 <- paste0("\"input.", foo[[1]][1], "=='", foo[[1]][2], "'", "\"")
    foo2
}

parseValues <- function(x) {
    if (is.na(x)) 
        return(x)
    x <- gsub(" ", "", x)
    foo <- strsplit(x, ",")
    foo2 <- paste(foo)
    foo2
}


panel1 <- function(p0) {
    p0$label <- paste0("\"", p0$prompt, "\"")
    p0$id <- paste0("\"", p0$field, "\"")
    p0$values <- sapply(p0$values, parseValues)
    p0$cond <- sapply(p0$cond, parseCond)
    p0$layout %<>% recode(radio = "radioButtons", checkbox = "checkboxInput", 
        text = "textInput", date = "dateInput", select = "selectInput")
    p0$label <- ifelse(p0$req == 1, paste0("requ(", p0$label, ")"), p0$label)
    
    p0$label <- ifelse(p0$layout == "radioButtons", paste0(p0$label, ",", 
        p0$values, ", inline=TRUE"), p0$label)
    p0$label <- ifelse(p0$layout == "textInput", paste0(p0$label, ", width='2.0in'"), 
        p0$label)
    
    p0$label <- ifelse(p0$layout == "selectInput", paste0(p0$label, ",", p0$values, 
        ", width='0.8in'"), p0$label)
    
    p0$label <- paste0(p0$layout, "(", p0$id, ",", p0$label, ")")
    p0$label <- ifelse(!is.na(p0$cond), paste0("conditionalPanel(condition =", 
        p0$cond, ",", p0$label, ")"), p0$label)
    p0$label <- paste0(p0$label, ",")
    
    p0
}

panelGen <- function(vis) {
    p0 <- panel0(vis)
    p1 <- panel1(p0)
    p1$table = sub('\\.[1-9]+$','',row.names(p1))
    tpn <- acb <- sl[sl$workingname %in% vf[[vis]], ]
    tpn$label <- paste0("tabPanel('", tpn$fullname, "', value = '", tpn$workingname, 
        "',")
    tpn$tp <- 1L
    tpn <- dplyr::rename(tpn, table = workingname)
    tpn <- select(tpn, table, label, tp)
    
    acb$label <- paste0("actionButton('submit", acb$workingname, "','submit', class='btn-info')),")
    acb$ac <- 1L
    acb <- dplyr::rename(acb, table = workingname)
    acb <- select(acb, table, label, ac)
    p7 = select(p1, field, cnt)
    p2 <- merge(tpn, p1, all = TRUE)
    p2 <- merge(acb, p2, all = TRUE)
    # add in relevant tooltips to the panel after action button
    
    #p7 = select(p2, table, field, tp, ac, cnt)
    #p2 <- dplyr::arrange(p2, table, tp, desc(is.na(ac)), cnt)
    p2 <- dplyr::arrange(p2, table, tp, !is.na(ac), cnt)
    
    p2$label[nrow(p2)] <- gsub("),$", ")", p2$label[nrow(p2)])
    pnl <- paste0("navlistPanel(id='form",vis,"',")

    write(c(pnl, p2$label, ")"), file = paste0(".forms/", vis, "panel"))
    saveRDS(eval(parse(text = paste(c(pnl, p2$label, ")"), coll = ""))), 
            file = paste0(".forms/", vis, "panel.rds"))
}

lapply(vl, panelGen)

# p0 = panel0(vis)
parseValid <- function(x) {
    if (is.na(x)) 
        return(TRUE)
    x <- str_replace_all(x, " ", "")
    x <- str_replace_all(x, "\\(", "")
    x <- str_replace_all(x, "\\)", "")
    foo0 <- unlist(str_extract_all(x, "[!=><]"))
    foo0 <- ifelse(length(foo0) > 1, paste0(foo0, collapse = ""), foo0)
    foo <- unlist(strsplit(x, foo0))
    inp0 <- paste0("input$", foo[1])
    inp0 <- ifelse(grepl("length", foo[2]), paste0("nchar(", inp0, ")"), inp0)
    foo2 <- paste0(inp0, foo0, "'", foo[2], "'")
    
    foo3 <- sub("'today'", "today()", foo2)
    
    foo4 <- sub("=", "==", foo3)
    foo4b <- sub("!==", "!=", foo4)
    foo4b <- sub("<==", "<=", foo4b)
    foo4b <- sub(">==", ">=", foo4b)
    foo5 <- sub("'length", "'", foo4b)
    foo6 <- ifelse(foo0 %in% c("<", ">"), gsub("'", "", foo5), foo5)
    foo6
}

# valid0 =
# dl[['validation']][,c('field','valid','errormsg','workingname')]
# valid0$valid =sapply(valid0$valid, parseValid)


# need a list of fields for each form
fnm <- paste0(".forms/fieldlist", names(dl), ".R")
for (i in 1:length(dl)) {
    dput(dl[[i]]$field, fnm[i])
}
# need a list of required fields for each form
fnmreq <- paste0(".forms/reqfieldlist", names(dl), ".R")
for (i in 2:(length(dl) - 2)) {
    rf <- dl[[i]] %>% filter(req == 1) %>% dplyr::select(., field, valid, 
        validmsg)
    rf$valid <- sapply(rf$valid, parseValid)
    dput(rf, fnmreq[i])
}

sites <- dl[["sites"]]
dput(sites$sitecode, paste0(".forms/sitelist.R"))


# dput(sl$workingname[-1], ".forms/formlist.R")


# dl <- mapply(cbind, dl, table = names(dl), stringsAsFactors = FALSE)
# 
# # add a variable to order the inputs