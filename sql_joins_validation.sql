-- ============================================
-- SQL Joins: Correctness and Validation
-- ============================================

-- Step 1: Base Join (Orders + Customers)
SELECT 
  o.order_id,
  o.order_date,
  c.customer_name,
  c.region
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id;

-- Step 2: Multi-table Join (All three tables)
SELECT 
  o.order_id,
  o.order_date,
  c.customer_name,
  c.region,
  oi.product,
  oi.quantity,
  oi.price,
  oi.quantity * oi.price AS revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- Step 3: Revenue Aggregation
SELECT 
  c.region,
  SUM(oi.quantity * oi.price) AS total_revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.region;

-- Step 4: Validation Queries
-- Check row counts
SELECT COUNT(*) AS joined_rows
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;

-- Validate revenue consistency
SELECT 
  SUM(oi.quantity * oi.price) AS total_revenue
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id;
