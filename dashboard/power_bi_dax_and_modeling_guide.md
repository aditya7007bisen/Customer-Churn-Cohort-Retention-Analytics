# Power BI Implementation, Data Modeling & DAX Reference Guide

## 1. Data Model Architecture (Star Schema)
To achieve fast performance and seamless filtering in Power BI:

### **Tables & Relationships:**
1. **Dim_Customers** (data/customers.csv)
   - Primary Key: customer_id
   - Attributes: signup_date, cohort_month, cquisition_channel, country, plan_tier, illing_cycle, support_tickets, vg_monthly_usage_hours, is_churned, churn_date, churn_reason
2. **Fact_Transactions** (data/transactions.csv)
   - Foreign Key: customer_id (1-to-Many relationship from Dim_Customers to Fact_Transactions)
   - Attributes: 	ransaction_id, 	ransaction_date, 	ransaction_month, mount, payment_status
3. **Dim_Date** (Generated in Power BI using DAX Calendar)
   - Relationship: Dim_Date[Date] (1) -> Fact_Transactions[transaction_date] (Many)

---

## 2. Core DAX Measures (Copy-Paste Ready)

Create a dedicated measure table called _Key_Measures:

### **Measure 1: Total Customer Base**
`dax
Total Customers = DISTINCTCOUNT(Dim_Customers[customer_id])
`

### **Measure 2: Churned Customers**
`dax
Churned Customers = 
CALCULATE(
    COUNTROWS(Dim_Customers),
    Dim_Customers[is_churned] = 1
)
`

### **Measure 3: Active Customers**
`dax
Active Customers = 
CALCULATE(
    COUNTROWS(Dim_Customers),
    Dim_Customers[is_churned] = 0
)
`

### **Measure 4: Overall Churn Rate (%)**
`dax
Churn Rate % = 
DIVIDE(
    [Churned Customers],
    [Total Customers],
    0
)
`

### **Measure 5: Current Monthly Recurring Revenue (MRR)**
`dax
Active MRR = 
CALCULATE(
    SUM(Dim_Customers[monthly_revenue]),
    Dim_Customers[is_churned] = 0
)
`

### **Measure 6: Lost MRR Due to Churn**
`dax
Lost MRR = 
CALCULATE(
    SUM(Dim_Customers[monthly_revenue]),
    Dim_Customers[is_churned] = 1
)
`

### **Measure 7: Average Customer Lifetime Value (CLV)**
`dax
Average CLV = 
AVERAGEX(
    Dim_Customers,
    CALCULATE(SUM(Fact_Transactions[amount]))
)
`

### **Measure 8: Cohort Retention Rate (%)**
`dax
Cohort Retention % = 
VAR InitialCohortUsers = 
    CALCULATE(
        DISTINCTCOUNT(Fact_Transactions[customer_id]),
        ALLEXCEPT(Fact_Transactions, Fact_Transactions[cohort_month])
    )
VAR ActiveInCurrentPeriod = DISTINCTCOUNT(Fact_Transactions[customer_id])
RETURN
    DIVIDE(ActiveInCurrentPeriod, InitialCohortUsers, 0)
`

---

## 3. Recommended Visual Layout

* **Top Header:** Title: *SaaS Customer Retention & Churn Intelligence Executive Dashboard*
* **Row 1 (KPI Cards):**
  1. [Active Customers]
  2. [Churn Rate %] (Target: < 5%)
  3. [Active MRR] ($)
  4. [Lost MRR] ($ in Red Alert)
  5. [Average CLV] ($)
* **Row 2 Left (Cohort Matrix):**
  - **Visual:** Matrix Visual
  - **Rows:** Fact_Transactions[cohort_month] (Format: YYYY-MM)
  - **Columns:** Cohort Index (Month 0, Month 1, Month 2... Month 11)
  - **Values:** [Cohort Retention %]
  - **Formatting:** Conditional Formatting -> Background Color -> Gradient (Lowest: Light Yellow #FFF2CC, Highest: Dark Blue #1F4E79).
* **Row 2 Right (Bar Chart):**
  - **Visual:** Clustered Bar Chart
  - **Y-Axis:** Dim_Customers[acquisition_channel]
  - **X-Axis:** [Churn Rate %]
* **Row 3 (Risk Diagnostic):**
  - **Line Chart:** Dim_Customers[support_tickets] vs [Churn Rate %]
  - **Donut Chart:** Churn Reasons Distribution
