# **Dynamic Rule Reloading and Database Integration for Shiny Forms**

## **1. Dynamic Rule Reloading (Spreadsheet-Based)**
### **A. Spreadsheet Format (`validation_rules.csv`)**
```csv
field,rule
age,age >= 18 && age <= 65
email,/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(email)
height,height > 50 && height < 250
bmi,weight / (height / 100) ** 2 > 15 && weight / (height / 100) ** 2 < 50
```

---

### **B. Lua Script to Convert CSV to JavaScript (`process_validation.lua`)**
```lua
local csv = require("luacsv")  -- Requires CSV parser library
local file = io.open("validation_rules.csv", "r")
local parsed_data = csv.parse(file:read("*all"))

local js_code = "const validationRules = {
"

for i, row in ipairs(parsed_data) do
    local field, rule = row[1], row[2]
    js_code = js_code .. string.format('    "%s": function(value) { return %s; },
', field, rule)
end

js_code = js_code .. "};
"
file:close()

local js_file = io.open("validation.js", "w")
js_file:write(js_code)
js_file:close()

print("Validation JavaScript generated successfully!")
```

---

### **C. Shiny App with Automatic Rule Reloading (`app.R`)**
```r
library(shiny)
library(shinyjs)
library(fs)

ui <- fluidPage(
    useShinyjs(),
    tags$head(tags$script(src = "validation.js")),  # Include JS dynamically
    titlePanel("Dynamic Validation Rules in Shiny"),
    
    sidebarLayout(
        sidebarPanel(
            numericInput("age", "Enter Age:", value = NULL),
            textInput("email", "Enter Email:"),
            numericInput("height", "Enter Height (cm):", value = NULL),
            numericInput("weight", "Enter Weight (kg):", value = NULL),
            actionButton("submit", "Submit"),
            verbatimTextOutput("validation_message")
        ),
        mainPanel()
    )
)

server <- function(input, output, session) {
    # Watch for changes in the validation rules file
    observe({
        invalidateLater(5000, session)  # Check every 5 seconds
        runjs("delete window.validationRules; $.getScript('validation.js');")
    })
    
    observeEvent(input$submit, {
        runjs("
            let ageValid = validationRules['age'](parseFloat($('#age').val()));
            let emailValid = validationRules['email']($('#email').val());
            let heightValid = validationRules['height'](parseFloat($('#height').val()));
            let bmi = parseFloat($('#weight').val()) / ((parseFloat($('#height').val()) / 100) ** 2);
            let bmiValid = validationRules['bmi'](bmi);
            
            let messages = [];
            if (!ageValid) messages.push('Invalid Age!');
            if (!emailValid) messages.push('Invalid Email!');
            if (!heightValid) messages.push('Invalid Height!');
            if (!bmiValid) messages.push('Invalid BMI!');
            
            if (messages.length > 0) {
                alert(messages.join('\n'));
            } else {
                alert('All inputs are valid!');
            }
        ");
    })
}

shinyApp(ui, server)
```

✔ **Every 5 seconds**, Shiny reloads `validation.js` if `validation_rules.csv` was modified.  
✔ The new validation rules apply **immediately** in the browser.  
✔ No need to restart the Shiny app.

---

## **2. Database Integration for Validation Rules**
Instead of a CSV file, the validation rules can be **stored in a database** (e.g., MySQL, PostgreSQL, SQLite).

### **A. Database Schema**
Table: **validation_rules**
```sql
CREATE TABLE validation_rules (
    field TEXT PRIMARY KEY,
    rule TEXT
);
```

Example data:
```sql
INSERT INTO validation_rules (field, rule) VALUES
('age', 'age >= 18 && age <= 65'),
('email', '/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(email)'),
('height', 'height > 50 && height < 250'),
('bmi', 'weight / (height / 100) ** 2 > 15 && weight / (height / 100) ** 2 < 50');
```

---

### **B. Lua Script to Fetch Rules from Database (`process_validation_db.lua`)**
```lua
local sqlite3 = require("lsqlite3")
local db = sqlite3.open("validation.db")

local js_code = "const validationRules = {
"

for row in db:nrows("SELECT * FROM validation_rules") do
    js_code = js_code .. string.format('    "%s": function(value) { return %s; },
', row.field, row.rule)
end

js_code = js_code .. "};
"
local js_file = io.open("validation.js", "w")
js_file:write(js_code)
js_file:close()

db:close()
print("Validation JavaScript generated from database successfully!")
```

This script queries the database and **generates `validation.js` dynamically**.

---

### **C. Modify Shiny to Fetch Rules from Database**
Modify the **Shiny `server` function** to reload validation rules **every 5 seconds**.

```r
server <- function(input, output, session) {
    observe({
        invalidateLater(5000, session)  # Reload every 5 seconds
        system("lua process_validation_db.lua")  # Run Lua script
        runjs("delete window.validationRules; $.getScript('validation.js');")
    })
}
```

✔ **Shiny queries the database every 5 seconds** and updates validation rules dynamically.  
✔ Users can **edit validation rules in the database**, and they apply instantly.  
✔ **No restart required**.

---

## **Comparison: Spreadsheet vs. Database**
| Feature | CSV-Based Dynamic Rules | Database-Based Dynamic Rules |
|---------|----------------------|----------------------|
| **Storage** | Local file | Centralized database |
| **Scalability** | Best for small teams | Ideal for large-scale use |
| **User Interface** | Spreadsheet | Web-based admin panel |
| **Performance** | Fast | Requires DB query |

---

## **Next Steps**
🔥 **Would you like an admin panel in Shiny to edit validation rules directly?**  
🔥 **Would you like to store validation rules in a NoSQL database (MongoDB)?**  
🚀 Let me know what enhancements you’d like! 🚀
