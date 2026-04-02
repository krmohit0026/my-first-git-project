

### **1\. The Schema & Ingestion Strategy**

We define a strict EVENT\_SCHEMA. In Spark Structured Streaming, this is crucial because it allows the engine to fail-fast if the source data format breaks, preventing "silent data corruption" in your Data Lake.

* **Max Offsets Per Trigger:** Set to 50,000. This acts as a "backpressure" mechanism, ensuring Spark doesn't try to ingest the entire Kafka backlog at once and crash the executor memory.

---

### **2\. Validation & The Dead Letter Queue (DLQ)**

This is a critical production pattern. Instead of letting one bad record (e.g., a null user\_id or a typo in action) crash the entire 24/7 pipeline, we use a "Splitter" pattern.

* **Valid Stream:** Continues to the Enrichment and Data Lake sinks.  
* **Invalid Stream:** Routed back to Kafka in the streaming.user.dead-letter topic. This allows us to inspect the bad data later without stopping the flow.

---

### **3\. Enrichment Logic: Business Intelligence at Scale**

We aren't just moving data; we are making it smarter.

* **Engagement Score:** We translate categorical actions into a numerical $Score \\in \\{-1, 0, 1, 3, 5, 7\\}$. This allows for mathematical avg() and sum() operations in the "Gold" layer.  
* **Temporal Features:** Adding hour\_of\_day and is\_peak\_hour allows downstream analysts to find patterns in user behavior relative to time-of-day without expensive recalculations.

---

### **4\. The Multi-Sink Architecture**

Spark allows us to fork the stream into multiple destinations:

| Sink | Mode | Trigger | Purpose |
| :---- | :---- | :---- | :---- |
| **Parquet (S3/HDFS)** | append | 1 minute | **Permanent Storage.** Partitioned by date and country for fast analytical queries (O(1) partition pruning). |
| **Console (Metrics)** | update | 30 seconds | **Real-time Monitoring.** Shows 5-minute tumbling windows of engagement. |
| **DLQ (Kafka)** | append | 30 seconds | **Error Handling.** Captures malformed events for debugging. |

---

### **5\. Watermarking & Late Data Handling**

We've implemented a **10-minute watermark**:

$$EventTime \> MaxEventTimeSeen \- 10 minutes$$  
This tells Spark: "Wait up to 10 minutes for late-arriving data." If a mobile user loses signal and their 'play' event arrives 4 minutes late, it will still be included in the correct 5-minute window aggregation. Anything later than 10 minutes is dropped to keep the state store from growing infinitely.

---

### **6\. Verification & Monitoring**

The monitor\_queries function is your "Mission Control."

* **Input Rows vs. Processed Rows:** If Input \> Processed, you have a bottleneck.  
* **State Rows:** High state row counts in windowed queries can indicate your watermark is too wide, leading to high memory usage.