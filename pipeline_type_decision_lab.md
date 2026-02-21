## **Individual Data Flow Analysis**

## **Data Flow 1: Transaction Fraud Detection**

### **Pipeline Decision**

* **Pipeline Type:** Streaming  
* **Architecture:** ETL  
* **Latency Target:** Sub-second (\<500ms)  
* **Target System:** Real-time ML Model Feature Store / Fraud Engine

### **Justification**

1. **Why this pipeline type?** Fraud detection requires immediate action. Batching even for a minute would result in financial loss before the model could flag a transaction.  
2. **Why this architecture (ETL)?** **PCI-DSS Compliance.** Sensitive card data must be tokenized/masked *before* it hits any storage or downstream model. Transformation must happen "in-flight."  
3. **Data flow description:** Payment Gateway → Stream Processor (Flink/Spark Streaming) → Tokenization Service → ML Model Inference → Fraud Flag/Approve.

### **Failure Strategy**

* **What fails?** Tokenization service downtime; Stream congestion during spikes.  
* **Recovery plan:** Implement a "Fail-Open" or "Fail-Closed" circuit breaker based on risk appetite; use a buffer (Kafka) to handle spikes.  
* **Idempotency:** High. Each transaction ID is unique; the stream processor ensures "exactly-once" semantics to prevent double-processing.

### **Trade-offs**

* **Chose ETL over ELT because:** Raw card data cannot land in a warehouse (ELT) even temporarily without violating PCI-DSS.  
* **Risk:** High complexity in maintaining real-time infrastructure.

---

## **Data Flow 2: Daily Financial Reporting**

### **Pipeline Decision**

* **Pipeline Type:** Batch (Nightly)  
* **Architecture:** ETL  
* **Latency Target:** Daily  
* **Target System:** Financial Data Mart (PostgreSQL or Snowflake)

### **Justification**

1. **Why this pipeline type?** Financial reconciliation relies on "frozen" snapshots of the day's end. Nightly batching ensures all accounts are settled.  
2. **Why this architecture (ETL)?** **SOX Compliance.** Calculations must be deterministic. By using ETL, we can run rigorous validation checks in an isolated environment before the "pennies" are committed to the dashboard.  
3. **Data flow description:** Core Banking → Extraction Script → Transformation/Validation Engine → Audited Reporting Table.

### **Failure Strategy**

* **What fails?** Source DB connection timeout; Reconciliation mismatch (data quality error).  
* **Recovery plan:** Automated retry for connections; Manual intervention/Alerting for data quality mismatches.  
* **Idempotency:** Yes. The pipeline uses "Overwrite" logic for the specific date partition, allowing safe re-runs.

### **Trade-offs**

* **Chose ETL over ELT because:** We need a strict "gatekeeper" to ensure regulatory reports match the core system perfectly before loading.

---

## **Data Flow 3: Customer 360 Profile**

### **Pipeline Decision**

* **Pipeline Type:** Hybrid (Lambda Architecture)  
* **Architecture:** ELT  
* **Latency Target:** Minutes to Hourly  
* **Target System:** Data Warehouse (Snowflake/BigQuery)

### **Justification**

1. **Why this pipeline type?** Mobile app events are streaming, but CRM data is API-based. A hybrid approach allows us to ingest both and join them in the warehouse.  
2. **Why this architecture (ELT)?** Flexibility. Marketing needs change weekly. Storing raw data in the warehouse allows them to adjust their "Customer 360" logic without changing the ingestion code.  
3. **Data flow description:** Multiple Sources → Ingestion Tool (Fivetran/Airbyte) → Raw Warehouse Tables → dbt Transformations → Customer 360 View.

### **Failure Strategy**

* **What fails?** API rate limits on CRM; Schema drift in mobile app events.  
* **Recovery plan:** Exponential backoff for APIs; Schema evolution handling in the warehouse.  
* **Idempotency:** Yes. Using `MERGE` statements ensures that re-running the job doesn't create duplicate customer records.

---

## **Data Flow 4: Application Logs**

### **Pipeline Decision**

* **Pipeline Type:** Streaming  
* **Architecture:** ELT  
* **Latency Target:** Seconds (for alerting) to Minutes  
* **Target System:** Data Lake (S3) \+ OpenSearch/Elasticsearch

### **Justification**

1. **Why this pipeline type?** SREs need real-time alerts. If a service goes down, a nightly batch is useless.  
2. **Why this architecture (ELT)?** High volume (10M/day). Pre-processing this much volume is expensive. It is cheaper to dump raw JSON into a lake and parse only what is needed for specific alerts or debug sessions.  
3. **Data flow description:** Microservices → Fluentd → Kafka/Kinesis → S3 (Raw) → Alerting Engine.

### **Failure Strategy**

* **What fails?** Log spike causing backpressure; Disk full on log forwarder.  
* **Recovery plan:** Auto-scaling stream clusters; TTL (Time-To-Live) policies to clear old logs automatically.  
* **Idempotency:** Low priority. Duplicate logs are annoying but rarely business-critical for debugging.

---

## **Data Flow 5: Partner Data Ingestion**

### **Pipeline Decision**

* **Pipeline Type:** Batch  
* **Architecture:** ETL  
* **Latency Target:** Weekly  
* **Target System:** Data Warehouse (Snowflake)

### **Justification**

1. **Why this pipeline type?** The partner only delivers files weekly via SFTP.  
2. **Why this architecture (ETL)?** **Security/NDA.** We must ensure that partner data is validated and restricted (unauthorized columns removed) before it reaches the general BI warehouse.  
3. **Data flow description:** Partner SFTP → Downloader → Encryption/Scrubbing → Validation → Warehouse.

### **Failure Strategy**

* **What fails?** SFTP server unavailable; Partner changes CSV format without notice.  
* **Recovery plan:** Scheduled polling; Schema validation check that "quarantines" the file if the columns are wrong.  
* **Idempotency:** Yes. Use the filename as a unique identifier to prevent re-processing the same weekly file.

---

## **Summary Architecture Table**

| Data Flow | Pipeline Type | Architecture | Latency | Target | Key Risk |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **1\. Fraud Detection** | Streaming | ETL | Sub-second | ML Model | Late decisions \= $$ loss |
| **2\. Financial Reporting** | Batch | ETL | Daily | Warehouse | Audit failure / Inaccuracy |
| **3\. Customer 360** | Hybrid | ELT | Minutes | Warehouse | Stale marketing data |
| **4\. Application Logs** | Streaming | ELT | Seconds | Lake/Search | Incident response delay |
| **5\. Partner Data** | Batch | ETL | Weekly | Warehouse | Compliance/NDA breach |

**Platform Architecture Overview**

\[Payment Gateway\]  ──(Stream)──\> \[Tokenization\] ──\> \[ML Engine\] ──\> \[Fraud Decision\]  
\[Core Banking\]     ──(Batch)───\> \[Val. Engine\]  ──\> \[Audited DB\] ──\> \[CFO Dashboard\]  
\[CRM/App/DB\]       ──(Mixed)───\> \[Raw Lake\]     ──\> \[dbt Models\] ──\> \[Marketing/Prod\]  
\[Microservices\]    ──(Stream)──\> \[Log Stream\]   ──\> \[S3/Search\]  ──\> \[SRE Alerts\]  
\[Partner SFTP\]     ──(Batch)───\> \[Encryption\]   ──\> \[BI Mart\]    ──\> \[BI Reports\]

## **Reflection Questions**

1. **Which data flow was hardest to decide? Why?** The **Customer 360** flow was the hardest because it combines high-volume streaming events with slow-moving API data. Balancing the need for "freshness" for product dashboards with the "flexibility" required by the marketing team led to a complex Hybrid/ELT decision.  
2. **Where did compliance most influence your architecture?** Compliance was the primary driver for **Fraud Detection** and **Partner Data**. In Fraud Detection, PCI-DSS forced an ETL approach to tokenize card data before storage, while the Partner Data NDA necessitated a strict ETL "scrubbing" gate to prevent unauthorized data exposure in the warehouse.  
3. **If you could use only ONE pipeline type (batch or streaming), which would you choose for this company and why?** I would choose **Streaming**. While batch is simpler for finance, a fintech company's survival depends on real-time fraud detection and system reliability (logs). You can always simulate batch by processing streams in windows, but you cannot easily force a batch system to provide sub-second fraud decisions.

