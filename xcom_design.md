## **Module: M14 – Advanced Orchestration**

Airflow's XCom system is a powerful but sensitive mechanism. Using it correctly ensures a scalable metadata database, while abusing it can lead to "Database Bloat" and scheduler instability.

---

## **Part 1: XCom vs External Storage Classification**

The golden rule of Airflow development: **XCom is for metadata, not for data.**

| \# | Data Item | Size Estimate | Classification | Reasoning |
| :---- | :---- | :---- | :---- | :---- |
| 1 | Row count (e.g., 1500) | \~10 bytes | **XCom** | Tiny scalar; essential for monitoring and conditional branching. |
| 2 | File path string | \~60 bytes | **XCom** | Reference to where the real data is stored. Ideal use case. |
| 3 | Pandas DataFrame (100K rows) | \~10 MB | **External Storage** | High memory/DB pressure. Should be saved as Parquet/CSV on S3. |
| 4 | Partition date string | \~10 bytes | **XCom** | Lightweight metadata used to coordinate downstream filtering. |
| 5 | Error message summary | \~50 bytes | **XCom** | Useful for alerting and diagnostic logs in the UI. |
| 6 | Model accuracy score | \~8 bytes | **XCom** | Single float; used to decide whether to deploy a model. |
| 7 | Full SQL query results | \~25 MB | **External Storage** | Results should stay in the DB or be exported to a file. |
| 8 | S3 bucket name | \~20 bytes | **XCom** | Configuration metadata that is globally useful. |
| 9 | Customer list (50K records) | \~15 MB | **External Storage** | Heavy JSON serialization will slow down the metadata DB. |
| 10 | Status flag ("success") | \~8 bytes | **XCom** | Basic state signaling between tasks. |
| 11 | Configuration JSON (3 keys) | \~50 bytes | **XCom** | Small dictionary; low overhead for passing task settings. |
| 12 | 500-row CSV contents | \~200 KB | **External Storage** | Even "small" files bloat the DB over thousands of DAG runs. |

## **Part 2: XCom Key Design for ETL Pipeline**

### **Naming Convention**

All XCom keys follow the pattern: `{task_name}_{data_description}`

### **XCom Contract**

| XCom Key | Value Type | Example Value | Producer | Consumer(s) |
| :---- | :---- | :---- | :---- | :---- |
| extract\_row\_count | int | 1500 | extract | validate, notify |
| extract\_file\_path | string | s3://bucket/raw/data.parquet | extract | validate |
| validate\_status | string | "passed" | validate | transform, notify |
| transform\_output\_path | string | s3://bucket/gold/data.parquet | transform | load |
| transform\_rows\_out | int | 1480 | transform | notify |
| load\_inserted\_count | int | 1480 | load | notify |
| load\_table\_name | string | "prod.sales\_report" | load | notify |

### **Design Questions**

1. **Why does `notify` consume from almost every task?** Because the final notification (Slack/Email) usually summarizes the entire journey: "Extracted 1500, Validated (Success), Loaded 1480 into `sales_report`."  
2. **Should `validate_error_summary` be a string or a list?** A string is safer for XCom. A list can grow indefinitely; a string summary (e.g., "Top 3 errors...") keeps the database size predictable.  
3. **What happens if `extract` fails and pushes no values?** Downstream tasks will pull `None`. Without checks, `validate` will crash with a `TypeError`.

### **XCom Data Flow**

---

## **Part 3: Identify XCom Anti-Patterns**

### **Anti-Pattern 1: Pushing a DataFrame**

**What's wrong:** The code converts a 100K-row DataFrame to a dictionary and pushes it to XCom. **Why it's dangerous:** This will cause a massive `INSERT` into the `xcom` table in the metadata DB. It can lead to "Long-running Transaction" locks, crashing the Airflow Scheduler. **Corrected code:**

def extract\_data(\*\*context):  
    df \= pd.read\_csv("s3://bucket/raw/transactions.csv")  
    path \= "s3://bucket/processed/data.parquet"  
    df.to\_parquet(path) \# Save to external storage  
    context\["ti"\].xcom\_push(key="file\_path", value=path) \# Push ONLY the path

### **Anti-Pattern 2: Pushing Large Query Results**

**What's wrong:** Pushing 50,000 rows as a raw JSON list. **Why it's dangerous:** Large JSON payloads require heavy CPU time to serialize/deserialize every time the task is viewed in the UI or pulled by a worker. **Corrected code:** Write results to a temporary table in the database and push the `table_name` or `row_count`.

### **Anti-Pattern 3: Not Handling Missing XCom**

**What's wrong:** Assuming `xcom_pull` always returns a value. **Why it's dangerous:** If an upstream task skips or fails silently, `None` is returned. Downstream code like `pd.read_csv(None)` will crash with obscure errors. **Corrected code:** Use `if val is None: raise AirflowFailException(...)` to provide clear debugging info.

### **Anti-Pattern 4: Tight Coupling**

**What's wrong:** Task B pulls 5+ individual keys from Task A. **Why it's dangerous:** If Task A is refactored, Task B breaks. It makes the DAG hard to maintain. **Corrected approach:** Consolidate into a single "Metadata Manifest" (a small dict) so Task B only performs one pull.

---

## **Anti-Pattern Summary**

| \# | Anti-Pattern | Root Cause | Fix |
| :---- | :---- | :---- | :---- |
| 1 | Pushing DataFrame | Treating XCom as storage | Save to S3/GCS, push path |
| 2 | Pushing large JSON | Size unawareness | Push DB table reference |
| 3 | No null check | Happy-path programming | Explicit None checks |
| 4 | Excessive Keys | Low modularity | Use a single Metadata Dict |

