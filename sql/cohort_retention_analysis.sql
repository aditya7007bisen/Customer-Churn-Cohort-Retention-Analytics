-- ==============================================================================
-- CUSTOMER CHURN & COHORT RETENTION ANALYTICS (SaaS / E-Commerce)
-- Author: Aditya Singh Bisen
-- Tech Stack: PostgreSQL / MySQL / BigQuery Compatible SQL
-- Objective: Calculate monthly cohort retention matrix, churn risk drivers, and LTV
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. BASE COHORT RETENTION MATRIX CALCULATION (CTEs + Window Functions)
-- ------------------------------------------------------------------------------
WITH customer_cohort AS (
    -- Step 1: Determine each customer's first activity month (Cohort Month)
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(transaction_date::DATE)) AS cohort_month
    FROM transactions
    WHERE payment_status = 'Success'
    GROUP BY customer_id
),

monthly_activity AS (
    -- Step 2: Map each transaction to transaction month and compute Cohort Index (Month 0, 1, 2...)
    SELECT 
        t.customer_id,
        c.cohort_month,
        DATE_TRUNC('month', t.transaction_date::DATE) AS transaction_month,
        -- Calculate the difference in months between cohort month and transaction month
        (EXTRACT(YEAR FROM t.transaction_date::DATE) - EXTRACT(YEAR FROM c.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM t.transaction_date::DATE) - EXTRACT(MONTH FROM c.cohort_month)) AS cohort_index
    FROM transactions t
    JOIN customer_cohort c ON t.customer_id = c.customer_id
    WHERE t.payment_status = 'Success'
    GROUP BY t.customer_id, c.cohort_month, DATE_TRUNC('month', t.transaction_date::DATE), t.transaction_date
),

cohort_size AS (
    -- Step 3: Count total initial customers in each cohort (Month 0 baseline)
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS total_cohort_users
    FROM customer_cohort
    GROUP BY cohort_month
),

retention_counts AS (
    -- Step 4: Count distinct active customers in each cohort for each subsequent month
    SELECT 
        m.cohort_month,
        m.cohort_index,
        COUNT(DISTINCT m.customer_id) AS active_users
    FROM monthly_activity m
    GROUP BY m.cohort_month, m.cohort_index
)

-- Step 5: Final Cohort Retention Rate (%) calculation
SELECT 
    TO_CHAR(r.cohort_month, 'YYYY-MM') AS cohort_period,
    s.total_cohort_users AS cohort_size,
    r.cohort_index,
    r.active_users,
    ROUND((r.active_users::NUMERIC / s.total_cohort_users::NUMERIC) * 100.0, 2) AS retention_rate_pct
FROM retention_counts r
JOIN cohort_size s ON r.cohort_month = s.cohort_month
ORDER BY r.cohort_month ASC, r.cohort_index ASC;


-- ------------------------------------------------------------------------------
-- 2. CHURN RATE BY ACQUISITION CHANNEL & BILLING CYCLE
-- Objective: Identify which channels bring sticky vs high-churn customers
-- ------------------------------------------------------------------------------
SELECT 
    acquisition_channel,
    billing_cycle,
    COUNT(customer_id) AS total_customers,
    SUM(is_churned) AS churned_customers,
    ROUND((SUM(is_churned)::NUMERIC / COUNT(customer_id)::NUMERIC) * 100.0, 2) AS churn_rate_pct,
    ROUND(AVG(monthly_revenue), 2) AS avg_monthly_revenue,
    ROUND(SUM(monthly_revenue * (1 - is_churned)), 2) AS active_mrr
FROM customers
GROUP BY acquisition_channel, billing_cycle
ORDER BY churn_rate_pct DESC;


-- ------------------------------------------------------------------------------
-- 3. THE 'MONTH 3 CLIFF' & SUPPORT TICKET CHURN CORRELATION
-- Finding: How support friction directly triggers customer cancellation
-- ------------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN support_tickets = 0 THEN '0 Tickets (Low Touch)'
        WHEN support_tickets BETWEEN 1 AND 2 THEN '1-2 Tickets (Normal)'
        WHEN support_tickets BETWEEN 3 AND 4 THEN '3-4 Tickets (At Risk)'
        ELSE '5+ Tickets (Critical Friction)'
    END AS support_ticket_tier,
    COUNT(customer_id) AS customer_count,
    SUM(is_churned) AS churned_count,
    ROUND((SUM(is_churned)::NUMERIC / COUNT(customer_id)::NUMERIC) * 100.0, 2) AS churn_rate_pct,
    ROUND(AVG(avg_monthly_usage_hours), 1) AS avg_usage_hours
FROM customers
GROUP BY 1
ORDER BY churn_rate_pct ASC;


-- ------------------------------------------------------------------------------
-- 4. NET REVENUE RETENTION (NRR) & CUSTOMER LIFETIME VALUE (CLV)
-- ------------------------------------------------------------------------------
WITH customer_revenue AS (
    SELECT 
        customer_id,
        SUM(amount) AS total_lifetime_spend,
        COUNT(DISTINCT transaction_month) AS active_billing_months
    FROM transactions
    WHERE payment_status = 'Success'
    GROUP BY customer_id
)
SELECT 
    c.plan_tier,
    COUNT(c.customer_id) AS total_customers,
    ROUND(AVG(r.total_lifetime_spend), 2) AS avg_customer_lifetime_value,
    ROUND(AVG(r.active_billing_months), 1) AS avg_customer_lifespan_months,
    ROUND(SUM(r.total_lifetime_spend), 2) AS total_plan_revenue
FROM customers c
JOIN customer_revenue r ON c.customer_id = r.customer_id
GROUP BY c.plan_tier
ORDER BY avg_customer_lifetime_value DESC;
