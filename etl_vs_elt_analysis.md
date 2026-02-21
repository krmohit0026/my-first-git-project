## **Step 1: Decision Framework**

### **Choose ETL when:**

* **Compliance:** Sensitive data must be cleaned/masked BEFORE loading.  
* **Compute Constraints:** Target system has limited compute (e.g., legacy DBs).  
* **Complexity:** Complex transformations require external tools (Python/Spark/ML).  
* **Format Requirements:** Legacy systems require specific, non-native formats.

### **Choose ELT when:**

* **Cloud Scale:** Target is a cloud warehouse (Snowflake, BigQuery).  
* **Flexibility:** Raw data should be preserved for future reprocessing.  
* **SQL-Centric:** Transformations are SQL-based (joins, aggregations).  
* **Speed:** Rapid ingestion is required (Load first, think later).

### **Choose Hybrid when:**

* **Multi-stage processing:** Some pre-load masking \+ post-load modeling.  
* **Diverse Sources:** Different sources have conflicting requirements.

---

## **Step 2: Scenario Analysis**

### **Scenario 1: Customer PII from CRM**

**Classification:** **ETL** **Where transformations happen:** External (Python/Middleware)

**Justification:**

1. **Compliance:** PII must be hashed *before* entering Snowflake to ensure raw sensitive data never touches the warehouse storage.  
2. **Data characteristics:** 50k records daily (Moderate volume).  
3. **Target system:** Snowflake (Capable of ELT, but compliance overrides it here). **Trade-offs:**  
* **Pro:** Maximum security and GDPR/CCPA compliance.  
* **Con:** Ingestion is slower due to the external processing hop. **Alternative considered:** ELT with Snowflake Data Masking; rejected because the requirement specifies masking *before* entering the warehouse.

### **Scenario 2: Web Clickstream Events**

**Classification:** **ELT** **Where transformations happen:** In-warehouse (BigQuery SQL)

**Justification:**

1. **Volume:** 10 million events daily (High velocity).  
2. **Usage:** Analysts need to explore raw events for discovery.  
3. **Target system:** BigQuery (Massively parallel compute). **Trade-offs:**  
* **Pro:** High ingestion speed and data flexibility.  
* **Con:** High storage costs if raw data is not eventually archived or pruned. **Alternative considered:** ETL; rejected as it would lose raw event context needed by data scientists.

### **Scenario 3: Financial Transaction Reconciliation**

**Classification:** **ETL** **Where transformations happen:** External (Python)

**Justification:**

1. **Complexity:** Requires Python-based fuzzy matching logic impossible in standard SQL.  
2. **Target system:** PostgreSQL (Limited compute for heavy analytical matching). **Trade-offs:**  
* **Pro:** Handles complex logic that SQL cannot.  
* **Con:** Scaling Python processing for higher volumes can be difficult. **Alternative considered:** ELT; rejected because PostgreSQL would struggle with the compute load of fuzzy matching.

### **Scenario 4: IoT Sensor Data**

**Classification:** **Hybrid** **Where transformations happen:** Both (Lambda/S3 \+ Snowflake SQL)

**Justification:**

1. **Characteristics:** 50M events daily; needs both raw storage (S3) and aggregated storage (Snowflake).  
2. **Pattern:** Raw data lands in S3 (ELT style), while refined summaries are transformed and loaded into Snowflake. **Trade-offs:**  
* **Pro:** Best of both worlds—ML-ready raw data and BI-ready summaries.  
* **Con:** Managing two storage layers increases architectural complexity. **Alternative considered:** Pure ELT; rejected as the volume might make Snowflake ingestion too expensive without pre-aggregation.

### **Scenario 5: HR Employee Data**

**Classification:** **ETL** **Where transformations happen:** External (Middleware)

**Justification:**

1. **Security:** Individual salaries must *never* enter the warehouse.  
2. **Compliance:** Data must be aggregated to the department level before the `LOAD` step. **Trade-offs:**  
* **Pro:** Guaranteed privacy for sensitive HR records.  
* **Con:** Any change in aggregation logic requires re-running the external pipeline. **Alternative considered:** ELT; rejected as raw salary data in Redshift poses a significant internal security risk.

### **Scenario 6: Product Catalog Updates**

**Classification:** **ELT** **Where transformations happen:** In-warehouse (Snowflake SQL)

**Justification:**

1. **Complexity:** Simple CDC and minor cleaning are easily handled by Snowflake tasks or dbt.  
2. **Volume:** 10k records (Small/Moderate). **Trade-offs:**  
* **Pro:** Extremely simple to maintain and monitor.  
* **Con:** Minor warehouse costs for cleaning tasks. **Alternative considered:** ETL; rejected as it adds unnecessary complexity to a simple SQL task.

---

## **Step 3: Classification Summary Table**

| Scenario | Source | Target | Classification | Transform Location | Key Factor |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 1\. Customer PII | CRM API | Snowflake | **ETL** | External | PII/Compliance |
| 2\. Clickstream | Kafka | BigQuery | **ELT** | In-warehouse | Data Exploration |
| 3\. Financial Recon | CSV | PostgreSQL | **ETL** | External | Fuzzy Matching Logic |
| 4\. IoT Sensor | MQTT | S3 \+ Snowflake | **Hybrid** | Both | Multi-layer storage |
| 5\. HR Employee | HR API | Redshift | **ETL** | External | Salary Privacy |
| 6\. Product Catalog | PostgreSQL | Snowflake | **ELT** | In-warehouse | Simple CDC |

### **Patterns Observed**

1. **Compliance-driven ETL:** Used when data sensitivity (PII, Salaries) prevents raw storage in the cloud.  
2. **Cloud-warehouse ELT:** Used when high-volume semi-structured data (JSON) needs to be explored by SQL-savvy teams.  
3. **Hybrid triggers:** Used when the architecture requires both a low-cost Data Lake for raw storage and a high-performance Warehouse for aggregations.

---

## **Step 4: Hybrid Architecture Design**

### **Data Flow Overview**

Our architecture utilizes a **Medallion Approach** inside a **Data Lakehouse**.

* **ETL Path:** Sensitive HR and PII data pass through a Python/Spark "Scrubbing" service before landing in the "Silver" zone of the warehouse.  
* **ELT Path:** Clickstream and Catalog data land in a "Bronze" raw zone (S3/BigQuery) and are transformed using SQL (dbt/Snowflake).

### **Architecture Layers**

* **Ingestion Layer:** FiveTran (SaaS), Kafka Connect (Streaming), and Custom Python Scripts (API).  
* **Transformation Layer:** \- **External:** AWS Lambda/Spark for PII masking and fuzzy matching.  
  * **In-warehouse:** dbt (Data Build Tool) for SQL modeling and aggregations.  
* **Storage Layer:**  
  * **Data Lake (S3):** Permanent home for raw IoT and Clickstream JSON.  
  * **Data Warehouse (Snowflake/BigQuery):** Home for modeled Business Intelligence data.

### **Architecture Diagram (Text-Based)**

\[Source Systems\] (CRM, Kafka, IoT, HR, SQL)  
      |  
      v  
\[Ingestion Layer\] (Airbyte / Kafka)  
   /          \\  
  v            v  
\[ETL Path\]   \[ELT Path\]  
 (Python)        |  
  |              v  
  v        \[Load Raw to Data Lake/Bronze\]  
\[Mask/Fuzzy      |  
 Transform\]      v  
  |        \[Load to Warehouse Silver Zone\]  
  v              |  
\[Load Clean to   v  
 Warehouse\]  \[SQL Transform (dbt)\]  
  |              |  
  \\\_\_\_\_\_\_\_\_\_\_\_\_\_\_/  
         |  
         v  
\[Analytics-Ready Data (Gold)\]  
