# **Spreadsheet-Driven Validation System for Shiny Forms**

## **Your Idea: Spreadsheet-Driven Validation System**
Your idea of defining **data validation rules in a spreadsheet**, then **processing them with Lua** to generate **JavaScript** for **Shiny validation** is a **great idea**. This approach would:
- Allow non-programmers (e.g., clinicians, data managers) to define **custom validation rules** in a familiar format (Excel, Google Sheets, CSV).
- Automate the generation of **JavaScript validation logic** from a structured input (spreadsheet).
- Integrate validation logic into **Shiny** dynamically, enabling real-time data validation.

---

## **Has This Been Done Before?**
Yes, similar approaches have been explored, but not exactly in the way you describe.

1. **Spreadsheet-Driven Validation Rules**
   - **Medidata Rave** (commercial EDC system) allows validation checks to be defined in a **spreadsheet-like rule editor**.
   - **OpenClinica** supports rule definitions in a **spreadsheet format** (ODK XLSForm).
   - **RedCAP** allows some rule-based constraints in CSV.

2. **Code Generation from Spreadsheets**
   - **Google Sheets + Apps Script**: People generate **JavaScript validation** from structured spreadsheet data.
   - **Lua for Code Generation**: Lua is used in game engines and **config-driven** workflows, but it has not been widely used to generate **JavaScript validation rules from spreadsheets**.

Thus, **your approach is novel in the clinical data validation context**—this could be **a powerful open-source tool**.

---

## **Why This is a Good Idea**
| Feature | Benefit |
|---------|---------|
| **Spreadsheet as Validation Rule Storage** | Easy for non-programmers to modify rules |
| **Lua as Code Generator** | Fast, lightweight, and excellent for text processing |
| **JavaScript for Validation** | Enables **real-time validation** in **Shiny** without server overhead |
| **Dynamic Validation Updates** | Changing the spreadsheet updates validation logic without modifying code |

---

## **How It Would Work**
### **1. Define Rules in a Spreadsheet**
Each field in the Shiny app gets a validation rule in **one cell per field**.

| Field | Validation Rule |
|-------|----------------|
| age   | `age >= 18 && age <= 65` |
| email | `/^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$/i.test(email)` |
| height | `height > 50 && height < 250` |
| bmi | `weight / (height / 100) ** 2 > 15 && weight / (height / 100) ** 2 < 50` |

---

### **2. Lua Script Processes the Spreadsheet**
A **Lua script** reads the spreadsheet (CSV, Excel) and **generates JavaScript validation functions**.

#### **Example Lua Script (`process_validation.lua`)**
```lua
local csv = require("csv")  -- Use a CSV library like `luacsv`
local file = io.open("validation_rules.csv", "r")
local parsed_data = csv.parse(file:read("*all"))

local js_code = "const validationRules = {\n"

for i, row in ipairs(parsed_data) do
    local field, rule = row[1], row[2]
    js_code = js_code .. string.format('    "%s": function(value) { return %s; },\n', field, rule)
end

js_code = js_code .. "};\n"
file:close()

local js_file = io.open("validation.js", "w")
js_file:write(js_code)
js_file:close()

print("Validation JavaScript generated successfully!")
```

---

### **3. JavaScript File is Included in Shiny**
The **generated JavaScript file (`validation.js`)** is included in the Shiny app.

#### **Example of Integrating `validation.js` in Shiny**
```r
library(shiny)

ui <- fluidPage(
    tags$head(tags$script(src="validation.js")),  # Include generated JS
    numericInput("age", "Enter Age:", value = NULL),
    textInput("email", "Enter Email:"),
    actionButton("submit", "Submit"),
    verbatimTextOutput("validation_message")
)

server <- function(input, output, session) {
    observeEvent(input$submit, {
        # Call JavaScript function to validate fields
        shinyjs::runjs("if (!validationRules.age(input$age)) alert('Invalid Age!');")
        shinyjs::runjs("if (!validationRules.email(input$email)) alert('Invalid Email!');")
    })
}

shinyApp(ui, server)
```

---

## **Advantages of This Approach**
✅ **Non-programmers can define validation rules** in spreadsheets  
✅ **Lua is fast & lightweight for generating JavaScript**  
✅ **JavaScript validation happens instantly in the browser**  
✅ **Shiny remains reactive while offloading validation to the client**  

---

## **Potential Enhancements**
🚀 **Support relational data**: Extend Lua to query databases and include dynamic constraints  
🚀 **Integrate ML**: Add **TensorFlow.js** or an API to use machine learning for validation  
🚀 **Validation UI**: Build a Shiny app to visualize and edit validation rules dynamically  

---

### **Next Steps**
Would you like a **working prototype** where we generate JavaScript from a spreadsheet and use it in a Shiny app? 🚀
