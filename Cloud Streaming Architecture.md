---

## **Deliverable 1: Architecture Diagram**

**The Data Flow:**

1. **Ingestion:** Web/Mobile (KPL/SDK) $\\rightarrow$ **AWS MSK**.  
2. **File/CDC:** Partner SFTP \+ DB $\\rightarrow$ **Apache NiFi** $\\rightarrow$ **AWS MSK**.  
3. **Speed Layer:** **Spark Structured Streaming** (running on EMR) reads from MSK.  
   * Path A: Aggregate metrics $\\rightarrow$ **Snowflake** (Real-time dash).  
   * Path B: Detect patterns $\\rightarrow$ **Kafka Alert Topic** (Viral alerting).  
4. **Batch/Lake Layer:** **MSK Connect (S3 Sink)** $\\rightarrow$ **S3 (Delta Lake)**.  
5. **Transformation:** **dbt** runs on **Snowflake** every 4 hours for business reporting.

---

## **Deliverable 2: Service Selection & Justification**

| Layer | Selected Service | Justification |
| :---- | :---- | :---- |
| **Ingestion** | **AWS MSK** | Managed Kafka reduces operational overhead for 3 engineers while handling high throughput (110K/sec) reliably. |
| **Processing** | **Spark Structured Streaming** | Better integration with the AWS ecosystem (EMR) and existing team familiarity with Spark/Python. |
| **File Ingestion** | **Apache NiFi** | Best-in-class for handling "messy" SFTP and CSV sources with built-in error handling and visual monitoring. |
| **Data Lake** | **S3 \+ Delta Lake** | Provides "ACID" transactions on S3, which is critical for GDPR (deleting specific user records). |
| **Batch** | **dbt on Snowflake** | Industry standard for SQL-based transformations with high performance for business reporting. |

---

## **Deliverable 3: Topic & Schema Design**

| Topic | Partitions | Key | Retention |
| :---- | :---- | :---- | :---- |
| streaming.raw.web | 60 | user\_id | 24 Hours |
| streaming.enriched.events | 60 | user\_id | 7 Days |
| streaming.alerts.viral | 6 | content\_id | 3 Days |
| streaming.dead-letter | 12 | event\_id | 14 Days |

*   
  **Partition Strategy:** 60 partitions allow for massive parallel consumption (matching 110K/sec throughput).  
* **Schema Format:** **Avro** (via Confluent Schema Registry). Avro is compact (saves $ on storage) and enforces strict schemas.

---

## **Deliverable 4: GDPR Compliance Flow**

**The "Routing" Decision:**

GDPR routing happens in the **Spark Streaming** layer.

* **Logic:** if country in EU\_LIST: send to eu-west-1 bucket / topics.  
* **Storage:** EU data is isolated in a physically separate AWS Region to comply with data residency laws.  
* **Deletion:** Deletion requests trigger a dbt/Spark job that performs a DELETE FROM DeltaTable WHERE user\_id \= X.

---

## **Deliverable 5: Cost Estimate ($15,000 Budget)**

| Service | Monthly Cost (Est) | Optimization Strategy |
| :---- | :---- | :---- |
| **AWS MSK** | $7,500 | Use m5.2xlarge with provisioned throughput. |
| **AWS EMR (Spark)** | $3,500 | Use **Spot Instances** for task nodes to save 60%. |
| **S3 Storage** | $1,200 | Use **Intelligent-Tiering** for automatic cost reduction. |
| **Snowflake** | $2,000 | Use "Auto-Suspend" (1 min) to stop costs when idle. |
| **Data Transfer** | $800 | Keep services in the same AZ where possible. |
| **TOTAL** | **$15,000** | **On Budget.** |

---

## **Deliverable 6: Executive Summary**

**StreamPulse's streaming architecture uses AWS MSK and Spark Structured Streaming** to handle **110,000 events/second** with **under 5 seconds** end-to-end latency. The architecture supports **real-time alerting, GDPR compliance, and business reporting** at an estimated monthly cost of **$15,000**. Key design decisions include utilizing **managed MSK** to minimize engineering overhead, implementing **Delta Lake on S3** for ACID compliance during user data deletions, and a **multi-region routing strategy** to ensure full GDPR data residency.

