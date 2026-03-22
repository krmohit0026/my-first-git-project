\-- Create orders table

CREATE TABLE orders (

  order\_id INT PRIMARY KEY,

  customer\_id INT,

  order\_date DATE,

  region VARCHAR(50),

  amount DECIMAL(10,2)

);

\-- Insert sample data

\-- For PostgreSQL:

INSERT INTO orders (order\_id, customer\_id, order\_date, region, amount)

SELECT

  generate\_series(1, 100000\) AS order\_id,

  (random() \* 1000)::INT AS customer\_id,

  CURRENT\_DATE \- (random() \* 365)::INT AS order\_date,

  (ARRAY\['North', 'South', 'East', 'West'\])\[floor(random() \* 4 \+ 1)\] AS region,

  (random() \* 1000 \+ 10)::DECIMAL(10,2) AS amount;

\-- For MySQL/SQLite, use a loop or insert statements

SELECT \* FROM orders

WHERE order\_date \>= '2024-01-01';

SELECT \* FROM orders

WHERE region \= 'North';

SELECT \* FROM orders

WHERE customer\_id \= 42;

CREATE INDEX idx\_orders\_order\_date ON orders(order\_date);

CREATE INDEX idx\_orders\_region ON orders(region);

CREATE INDEX idx\_orders\_customer\_id ON orders(customer\_id);

\-- PostgreSQL

SELECT indexname, indexdef

FROM pg\_indexes

WHERE tablename \= 'orders';

\-- MySQL

SHOW INDEXES FROM orders;

\-- Drop indexes temporarily

DROP INDEX IF EXISTS idx\_orders\_order\_date;

DROP INDEX IF EXISTS idx\_orders\_region;

DROP INDEX IF EXISTS idx\_orders\_customer\_id;

\-- Time an INSERT

INSERT INTO orders (order\_id, customer\_id, order\_date, region, amount)

VALUES (100001, 500, CURRENT\_DATE, 'North', 250.00);

CREATE INDEX idx\_orders\_order\_date ON orders(order\_date);

CREATE INDEX idx\_orders\_region ON orders(region);

CREATE INDEX idx\_orders\_customer\_id ON orders(customer\_id);

\-- Time the same INSERT

INSERT INTO orders (order\_id, customer\_id, order\_date, region, amount)

VALUES (100002, 501, CURRENT\_DATE, 'South', 300.00);

---

## **Step 1: Baseline Performance (The "Slow" Way)**

When you run those SELECT queries without indexes, MySQL has to look at every single one of the 100,000 rows to see if they match your WHERE clause.

* **The Command:** EXPLAIN SELECT \* FROM orders WHERE customer\_id \= 42;  
* **What to look for:** In the output, the type column will say **"ALL"**. This means a **Full Table Scan**.  
* **The Logic:** It’s like looking for a specific word in a 500-page book by reading every single page from the beginning.

---

## **Step 2: Adding Indexes (The "Fast" Way)**

An index creates a separate, sorted list (usually a **B-Tree**) that points to the location of the data.

SQL

CREATE INDEX idx\_orders\_customer\_id ON orders(customer\_id);  
CREATE INDEX idx\_orders\_order\_date ON orders(order\_date);  
CREATE INDEX idx\_orders\_region ON orders(region);

* **The Change:** Now, when you run EXPLAIN, the type column will change from "ALL" to **"ref"** or **"range"**.  
* **The Logic:** This is like using the **Index** at the back of a book. You look up "Customer 42," find the page number, and jump straight there.

---

## **Step 3: Performance Comparison**

You will likely notice a massive difference in the customer\_id and order\_date queries, but perhaps less of a difference in the region query.

| Query | Before (Scan) | After (Index) | Why? |
| :---- | :---- | :---- | :---- |
| customer\_id \= 42 | \~20-50ms | \~1-2ms | **High Cardinality:** Only a few rows match, so the index is very efficient. |
| order\_date \>= ... | \~30ms | \~5ms | **Range Scan:** The B-Tree allows MySQL to find the start date and read sequentially. |
| region \= 'North' | \~40ms | \~15ms | **Low Cardinality:** Since "North" is 25% of the data, the index helps less than it does for unique IDs. |

---

## **Step 4: Index Cost Analysis (The "Trade-off")**

This is the most important part of the lesson. **Indexes are not free.**

#### **1\. Why do they speed up reads?**

They reduce the **I/O**. Instead of reading 100,000 rows from the disk, the database only reads the 5-10 "nodes" of the B-Tree and the specific rows it needs.

#### **2\. Why do they slow down writes (INSERT)?**

Imagine you have a physical address book.

* **Without an index:** You just scribble a new name on the first empty line you find. (Fast)  
* **With an index:** You have to find the correct alphabetical spot for the new name, move things around to fit it in, and update the "Table of Contents." (Slow)  
* **In MySQL:** Every time you INSERT a row, MySQL must update **four** different things: the table itself \+ the 3 indexes you created.

#### **3\. Why are too many indexes harmful?**

* **Storage:** Every index takes up disk space. Sometimes the indexes can be larger than the actual data\!  
* **Write Heavy Apps:** If you have an app that inserts 1,000 rows per second, adding 10 indexes might crash your performance.  
* **Optimizer Confusion:** Sometimes the database gets "confused" by too many choices and picks a sub-optimal index.

