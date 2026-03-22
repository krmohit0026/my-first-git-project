This task focuses on **Query Optimization**, which is the art of making the database work smarter, not harder. Since we are using **MySQL**, I have adapted the PostgreSQL generate\_series logic to MySQL-compatible syntax so you can actually run this on your machine.

---

## **Step 1: Capture Execution Plan (The Setup)**

First, let's get your data ready. Use this script to create your tables and populate them efficiently in MySQL:

SQL

\-- 1\. Create Tables  
CREATE TABLE customers (  
  customer\_id INT PRIMARY KEY,  
  name VARCHAR(100),  
  email VARCHAR(100),  
  city VARCHAR(50),  
  country VARCHAR(50)  
);

CREATE TABLE orders (  
  order\_id INT PRIMARY KEY,  
  customer\_id INT,  
  order\_date DATE,  
  amount DECIMAL(10,2),  
  status VARCHAR(20)  
);

\-- 2\. Populate Customers (10,000 rows)  
SET SESSION cte\_max\_recursion\_depth \= 10000;  
INSERT INTO customers  
WITH RECURSIVE seq AS (  
    SELECT 1 AS n UNION ALL SELECT n \+ 1 FROM seq WHERE n \< 10000  
)  
SELECT   
    n,   
    CONCAT('Customer ', n),   
    CONCAT('cust', n, '@example.com'),  
    ELT(FLOOR(1 \+ RAND() \* 4), 'New York', 'London', 'Tokyo', 'Paris'),  
    ELT(FLOOR(1 \+ RAND() \* 4), 'USA', 'UK', 'Japan', 'France')  
FROM seq;

\-- 3\. Populate Orders (100,000 rows)  
SET SESSION cte\_max\_recursion\_depth \= 100000;  
INSERT INTO orders  
WITH RECURSIVE seq AS (  
    SELECT 1 AS n UNION ALL SELECT n \+ 1 FROM seq WHERE n \< 100000  
)  
SELECT   
    n,   
    FLOOR(1 \+ RAND() \* 10000),   
    DATE\_SUB(CURDATE(), INTERVAL FLOOR(RAND() \* 365) DAY),  
    ROUND(10 \+ RAND() \* 1000, 2),  
    ELT(FLOOR(1 \+ RAND() \* 3), 'pending', 'completed', 'cancelled')  
FROM seq;

#### **Run your Base EXPLAINs:**

Run these and look at the type and rows columns:

* EXPLAIN SELECT \* FROM orders WHERE order\_date \>= '2024-01-01' AND amount \> 500;  
* EXPLAIN SELECT c.name, o.order\_id, o.amount FROM customers c JOIN orders o ON c.customer\_id \= o.customer\_id WHERE c.city \= 'New York';

---

## **Step 2: Identify Red Flags**

When you look at the results above, you will see "Red Flags" that indicate the database is struggling.

| Query Type | Red Flag | Impact | Severity |
| :---- | :---- | :---- | :---- |
| **WHERE Query** | type: ALL | Scans all 100k rows just to find a few dates. | **High** |
| **JOIN Query** | type: ALL on both | Performs a "Cartesian product" style check; very slow. | **Critical** |
| **JOIN Query** | Using join buffer | Memory-intensive; indicates missing indexes on Join keys. | **Medium** |

---

## **Step 3: Apply Optimizations**

Now, let's fix the bottlenecks by giving the database "maps" (indexes) and better instructions.

#### **The "Index" Fix:**

SQL

CREATE INDEX idx\_orders\_customer\_id ON orders(customer\_id);  
CREATE INDEX idx\_customers\_city ON customers(city);  
CREATE INDEX idx\_orders\_composite ON orders(order\_date, amount);

#### **The "Smarter Query" Fix:**

Instead of using functions in your WHERE clause (which kills indexes), use raw values.

* **Bad:** WHERE YEAR(order\_date) \= 2024 (Forces a full scan because MySQL must calculate the year for every row).  
* **Good:** WHERE order\_date \>= '2024-01-01' AND order\_date \<= '2024-12-31' (Allows the index to "jump" to the start date).

---

## **Step 4: Optimization Summary**

After applying the indexes, run the EXPLAIN again. You should see the type change to ref or range and the rows count drop significantly.

| Query | Before (Rows Scanned) | After (Rows Scanned) | Improvement |
| :---- | :---- | :---- | :---- |
| **Simple SELECT** | 1 (Primary Key) | 1 (Primary Key) | 0% (Already optimal) |
| **WHERE (Date/Amt)** | 100,000 | \~5,000 | **95% Faster** |
| **JOIN (City)** | 10,000 \* 100,000 | \~2,500 \* 10 | **99% Faster** |

---

## **Why this is faster:**

1. **SARGability:** By writing order\_date \>= ..., the query becomes **S**earch **A**rgument **Able**. The database can use the B-Tree to find the exact starting point.  
2. **Join Efficiency:** By indexing customer\_id in the orders table, the database can take a customer from the "New York" list and instantly find their orders instead of searching the entire orders table for every single customer.

