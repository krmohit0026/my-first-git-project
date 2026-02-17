-- ============================================
-- SQL Analytics: Python vs SQL Responsibilities
-- ============================================

-- Step 1: Revenue Calculation
SELECT 
  order_id,
  order_date,
  customer_id,
  region,
  product,
  quantity,
  price,
  quantity * price AS revenue
FROM sales;

-- Step 2: Total Revenue per Region
SELECT 
  region,
  SUM(quantity * price) AS total_revenue,
  COUNT(*) AS order_count
FROM sales
GROUP BY region
ORDER BY total_revenue DESC;

-- Step 3: Total Revenue per Product
SELECT 
  product,
  SUM(quantity * price) AS total_revenue,
  SUM(quantity) AS total_quantity_sold,
  COUNT(*) AS order_count
FROM sales
GROUP BY product
ORDER BY total_revenue DESC;

-- Step 4: Average Order Value
SELECT 
  AVG(quantity * price) AS avg_order_value
FROM sales;

-- Step 5: Daily Revenue Trend
SELECT 
  order_date,
  SUM(quantity * price) AS daily_revenue,
  COUNT(*) AS daily_orders
FROM sales
GROUP BY order_date
ORDER BY order_date;

-- Step 6: Validation Queries
-- Check total revenue consistency
SELECT 
  SUM(quantity * price) AS total_revenue
FROM sales;

-- Verify no duplicates
SELECT 
  order_id,
  COUNT(*) AS occurrence_count
FROM sales
GROUP BY order_id
HAVING COUNT(*) > 1;
