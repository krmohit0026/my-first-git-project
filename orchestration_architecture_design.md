## **Dependency Mapping**

Understanding the "critical path" is essential. The `orders_etl` is our primary bottleneck; if it fails, the majority of downstream analytics (Reports, ML, Quality) stalls.

---

## **Step 2: Grouping Pipelines into DAGs**

We will group these into **four distinct DAGs** based on their business domain and schedule.

### **1\. DAG: `sales_core_pipeline`**

* **Pipelines:** `orders_etl` (High priority), `customer_360` (Sequential dependency).  
* **Schedule:** `@daily` (2 AM).  
* **Why:** These are tightly coupled. `customer_360` cannot function without the order data. Keeping them in one DAG simplifies monitoring for the core sales flow.

### **2\. DAG: `inventory_mgmt_pipeline`**

* **Pipelines:** `inventory_sync` (Source), `product_catalog` (Downstream).  
* **Schedule:** `0 */4 * * *` (Every 4 hours).  
* **Why:** This runs on a different frequency than the daily sales reports. It must be independent to prevent sales delays from blocking catalog updates.

### **3\. DAG: `analytics_and_reporting_pipeline`**

* **Pipelines:** `daily_reports`, `weekly_analytics`, `ml_feature_pipeline`.  
* **Schedule:** `@daily` (6 AM).  
* **Why:** These represent the consumption layer. They consume data from the previous two DAGs.

### **4\. DAG: `observability_pipeline`**

* **Pipelines:** `data_quality_checks`.  
* **Schedule:** Triggered via Dataset updates.  
* **Why:** This acts as a global monitor. By keeping it separate, we can run quality checks across different domains without bloating the individual ingest DAGs.

---

## **Step 3: Cross-DAG Dependencies**

We will use **Airflow Datasets** (introduced in 2.4+) for a data-driven approach.

* **Mechanism:** `Dataset`  
* **Workflow:** When `sales_core_pipeline` finishes writing to the `orders` table, it updates a URI: `s3://shopstream/gold/orders`.  
* **Why this mechanism?** It removes the "Sensor" overhead. The downstream DAGs don't "poll" or wait; they are automatically triggered by the arrival of new data.  
* **Fallback:** If `orders_etl` fails, the Dataset is never updated, and downstream reporting DAGs do not run, preventing the "Garbage In, Garbage Out" scenario.

---

## **Step 4: Executor Decision**

### **Recommended Executor: LocalExecutor**

**Justification:**

1. **Parallelism:** With 8 pipelines and roughly 15-20 total tasks, a `LocalExecutor` on a moderately sized VM (e.g., 4 vCPUs, 16GB RAM) can easily handle 10+ concurrent tasks.  
2. **Operational Complexity:** The team of 6 engineers is currently migrating. `LocalExecutor` is the "middle ground"—it offers parallel task execution without the massive infrastructure overhead of `Celery` (Redis/RabbitMQ) or `Kubernetes`.  
3. **Growth:** This will serve ShopStream effectively until the team reaches \~15 engineers or 50+ DAGs, at which point a move to `KubernetesExecutor` would be appropriate.

---

## **Step 5: Failure Handling & Recovery**

### **DAG: `sales_core_pipeline` (Critical Path)**

* **Retry Policy:** 3 retries, 5-minute exponential backoff.  
* **Alerting:** Critical Slack alert \+ PagerDuty if it fails after the 3rd retry.  
* **Recovery:** Idempotent via SQL `MERGE` or overwrite-by-partition. It can be safely re-run without duplicating orders.

### **Scenario: `inventory_sync` API Timeout**

* **Handling:** Set `retries: 5` with a longer backoff (10 mins). Since it has a 10% failure rate, we only send a "Warning" to Slack on the first 3 failures, and a "Critical" alert only if the task fails entirely after all retries.

Deliverable 1: Summary Architecture Table

| Pipeline | Assigned DAG | Schedule | Criticality | Cross-DAG Dependency |
| :---- | :---- | :---- | :---- | :---- |
| **orders\_etl** | sales\_core | @daily 2AM | **HIGH** | Produces orders Dataset |
| **inventory\_sync** | inventory\_mgmt | \*/4 hours | MEDIUM | Internal |
| **daily\_reports** | analytics | @daily 6AM | **HIGH** | Consumes orders Dataset |
| **data\_quality** | observability | Data-driven | **HIGH** | Consumes all Datasets |

#### **Deliverable 2: Architecture Diagram**

┌─────────────────────────────────────────────────────────────────┐  
│                    AIRFLOW ORCHESTRATION                        │  
├─────────────────────────────────────────────────────────────────┤  
│                                                                 │  
│  DAG: sales\_ingest\_daily           DAG: inventory\_sync\_4hr      │  
│  ┌──────────┐                      ┌──────────────┐             │  
│  │orders\_etl│──┐                   │inventory\_sync│──┐          │  
│  └──────────┘  │                   └──────────────┘  │          │  
│        │       v                          │          v          │  
│        │    ┌──────────────┐              │   ┌───────────────┐ │  
│        │    │customer\_360  │              │   │product\_catalog│ │  
│        │    └──────────────┘              │   └───────────────┘ │  
│        │           │                      │           │         │  
│        ▼           ▼                      ▼           ▼         │  
│    (Dataset)   (Dataset)              (Dataset)   (Dataset)     │  
│        │           │                      │           │         │  
│  ┌─────┴───────────┴──────────────────────┴───────────┴──────┐  │  
│  │            DAG: analytics\_reporting\_daily                 │  │  
│  │  ┌──────────────────┐          ┌──────────────┐           │  │  
│  │  │ml\_feature\_pipeline│          │daily\_reports │           │  │  
│  │  └──────────────────┘          └──────────────┘           │  │  
│  │                                        │                  │  │  
│  │                                        v                  │  │  
│  │                               ┌──────────────────┐        │  │  
│  │                               │weekly\_analytics  │        │  │  
│  │                               └──────────────────┘        │  │  
│  └────────────────────────────────────────┬──────────────────┘  │  
│                                           │                     │  
│  DAG: quality\_observability               │                     │  
│  ┌─────────────────────┐                  │                     │  
│  │data\_quality\_checks  │ \<────────────────┘                     │  
│  └─────────────────────┘                                        │  
│                                                                 │  
│  Executor: LocalExecutor | Workers: 1 (Sequential) | Queue: N/A │  
├─────────────────────────────────────────────────────────────────┤  
│  Metadata DB: PostgreSQL  │  Webserver: port 8080               │  
└─────────────────────────────────────────────────────────────────┘

## **Deliverable 3: Reflection Questions**

1. **Which grouping decision was hardest? Why?** Deciding whether to put `daily_reports` and `weekly_analytics` together was difficult. While they share logic, the weekly job takes 50% longer. I chose to keep them in one `analytics` DAG but use conditional logic to skip the weekly task on non-Mondays to keep the UI clean.  
2. **If the team grows from 6 to 20 engineers, which part of this architecture would you change first? Why?** I would migrate to **KubernetesExecutor**. With 20 engineers, the number of DAGs will explode, and a single VM (`LocalExecutor`) will face resource contention. K8s allows for "Isolation," ensuring one engineer's buggy code doesn't crash the whole Airflow instance.  
3. **What is the single biggest risk?** The "Critical Path" from `orders_etl` to `daily_reports`. If the source DB is slow, every single downstream analytics task is delayed. Mitigation involves setting an **SLA (Service Level Agreement)** callback in Airflow to notify the team at 4 AM if the ingest hasn't finished yet.

