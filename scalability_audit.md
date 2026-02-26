# **StreamPulse Infrastructure: Scalability Audit Report**

**Date:** February 26, 2026

**Scope:** Evaluation of five core data pipelines against a 30% YoY growth projection on a single-node 64GB RAM architecture.

---

## **Executive Summary**

The StreamPulse data infrastructure is currently at a critical inflection point. Two of the five primary pipelines (**A** and **B**) are either currently failing or will fail due to memory exhaustion within the next 6 months. While the current single-server setup is sufficient for metadata and A/B testing, the core analytical and recommendation engines require immediate migration to distributed computing (Spark) or significant memory-optimization strategies to maintain operational stability.

---

## **Individual Pipeline Analysis**

### **Pipeline A: Daily Play Counts**

**Bottleneck:** **Memory (RAM)** **Current Utilization:** 58 GB / 64 GB (91%)

**Risk Level:** **CRITICAL** **Reason:** Pandas loads data into memory with significant overhead. With a 30% growth rate, the file size will reach 15.6 GB next year, pushing memory requirements toward 75 GB, which will trigger a `MemoryError` and crash the nightly batch.

**Timeline to failure:** 6–8 months.

**Recommendation:** \* **Immediate:** Use `usecols` in `pd.read_csv` to load only the 3 required columns (`song_id`, `artist_id`, `played_at`). This should reduce memory footprint by \~70%.

* **Strategic:** Migrate to **Apache Spark** to handle partitioning and out-of-core processing.

---

### **Pipeline B: User Recommendation Model**

**Bottleneck:** **Compute (CPU / Sequential Logic)** **Current Utilization:** 9 hours / 6-hour window (150% Time Utilization)

**Risk Level:** **CRITICAL** **Reason:** The pipeline is already broken, exceeding the nightly batch window by 3 hours. Because it uses a sequential Python loop to score 5 million users, it cannot take advantage of the 16 available CPU cores effectively.

**Recommendation:**

* **Immediate:** Refactor the sequential loop into a vectorized NumPy operation or use Python's `multiprocessing` library to parallelize scoring across the 16 cores.  
* **Strategic:** Implement **Spark MLlib** to distribute the similarity matrix computation across a cluster.

---

### **Pipeline C: Song Metadata Sync**

**Bottleneck:** **I/O (Network Latency)** **Current Utilization:** 25 minutes / 6-hour window

**Risk Level:** **LOW** **Reason:** The data volume is negligible (50 MB). While sequential API calls are slow, the 25-minute runtime is well within the 6-hour buffer. **Recommendation:** No architectural change needed. If runtime increases, implement asynchronous requests using `aiohttp` to parallelize API calls.

---

### **Pipeline D: Revenue Attribution**

**Bottleneck:** **Memory (Joins/Shuffling)** **Current Utilization:** 52 GB / 64 GB (81%)

**Risk Level:** **MEDIUM/HIGH** **Reason:** Complex joins in Pandas create massive intermediate objects. The memory spike to 52 GB leaves only 12 GB of overhead. A 30% growth in the `plays` table will likely cause a memory crash during the join phase within 12 months.

**Recommendation:**

* **Short-term:** Offload the join to the **PostgreSQL** layer (SQL Pushdown). Databases are highly optimized for joins and use disk-based sorting if RAM is tight.  
* **Long-term:** Migrate to Spark for "Shuffle Joins" as the data scales beyond the capacity of a single SQL node.

---

### **Pipeline E: A/B Test Analytics**

**Bottleneck:** **None (Well-sized)** **Current Utilization:** 8 minutes / 3 GB RAM

**Risk Level:** **LOW** **Reason:** This is a "small data" problem. The 1.5 GB total data for active experiments is handled efficiently by the current stack. **Recommendation:** **Keep in Pandas.** The overhead of Spark or distributed systems would likely make this pipeline slower due to network latency and coordination.

## **Scalability Audit Summary Table**

| Pipeline | Bottleneck | Data Size | Runtime | Memory | Risk | Recommendation |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| **A: Daily Play Counts** | Memory | 12 GB | 2.5h | 58 GB | **CRITICAL** | Column pruning; Migrate to Spark |
| **B: User Recommendations** | CPU/Time | 1B values | 9h | 22 GB | **CRITICAL** | Vectorization; Parallelize scoring |
| **C: Song Metadata Sync** | I/O | 50 MB | 25m | 0.2 GB | **LOW** | No change required |
| **D: Revenue Attribution** | Memory/Join | 15 GB | 4.5h | 52 GB | **MEDIUM** | SQL Pushdown; Memory optimization |
| **E: A/B Test Analytics** | None | 1.5 GB | 8m | 3 GB | **LOW** | No change required |

## **Migration Priority Roadmap**

### **Priority 1 — Immediate (This Month)**

* **Pipeline:** **User Recommendation Model (B)**  
* **Reason:** It is already failing to meet the SLA (9h vs 6h window).  
* **Action:** Parallelize the scoring loop using `multiprocessing` or move to a vectorized Spark ML approach.

### **Priority 2 — Short-term (Next 2 Sprints)**

* **Pipeline:** **Daily Play Counts (A)**  
* **Reason:** Imminent memory crash within months.  
* **Action:** Implement `usecols` and early data filtering. Start POC for Spark local mode.

### **Priority 3 — Medium-term (Next Quarter)**

* **Pipeline:** **Revenue Attribution (D)**  
* **Reason:** High memory usage during joins will become a risk by end-of-year.  
* **Action:** Transition logic to SQL inside PostgreSQL to leverage its query optimizer.

### **No Migration Needed**

* **Pipelines:** **Song Metadata Sync (C)** and **A/B Test Analytics (E)**.  
* **Reason:** Data volumes are small enough that distributed computing would be an anti-pattern (over-engineering).

