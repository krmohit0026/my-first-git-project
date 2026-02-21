**Part 1: Cron Expression Answers**

| \# | Requirement | Cron Expression | Explanation |
| :---- | :---- | :---- | :---- |
| 1 | Daily at 2 AM | 0 2 \* \* \* | 0th minute, 2nd hour, every day. |
| 2 | Hourly at :15 | 15 \* \* \* \* | 15th minute of every hour. |
| 3 | Monday 6 AM | 0 6 \* \* 1 | 0th minute, 6th hour, day of week 1 (Monday). |
| 4 | 1st of month midnight | 0 0 1 \* \* | 0th minute, 0th hour, 1st day of month. |
| 5 | Every 15 min | \*/15 \* \* \* \* | Every 15th minute interval. |
| 6 | Weekdays 8 AM | 0 8 \* \* 1-5 | 8 AM, Monday (1) through Friday (5). |

## **Part 2: Pipeline Scheduling Design**

### **Pipeline 1: Nightly Warehouse Refresh**

**Scheduling Strategy:** Dependency-aware (preferred) or Time-based with buffer. **Schedule/Trigger:** \- **Dependency-aware:** Trigger upon successful completion of Source DB backup.

* **Time-based:** `0 2 * * *` (2 AM). **Justification:** The source backup ends "around 1 AM." A fixed cron at 1:05 AM is risky. Triggering based on the backup completion event ensures the DB is ready and avoids resource contention. **Failure handling:** Retry up to 3 times. Idempotent via `TRUNCATE` and `LOAD` (Full Reload).

### **Pipeline 2: Hourly Clickstream Aggregation**

**Scheduling Strategy:** Event-based. **Schedule/Trigger:** Trigger when a new file is detected in the S3 bucket. **Justification:** Files appear at irregular intervals (:05 to :10). Cron would either run too early (missing data) or too late (increasing latency). **Failure handling:** Move failed files to a "dead-letter" folder. Idempotent via atomic file processing (checkpointing).

### **Pipeline 3: Financial Close Pipeline**

**Scheduling Strategy:** Dependency-aware (DAG). **Schedule/Trigger:** Upstream trigger (Step 1 starts on the 1st of the month at midnight: `0 0 1 * *`). **Justification:** Each step is strictly sequential. If Step 2 starts before Step 1 finishes, the data will be corrupt. **Failure handling:** Stop the DAG on failure. Manual resume. Idempotent via "Overwrite by Month" logic.

### **Pipeline 4: Partner File Ingestion**

**Scheduling Strategy:** Event-based. **Schedule/Trigger:** S3/SFTP Sensor (File arrival trigger). **Justification:** Partners upload at unpredictable times. Checking every 5 minutes (Cron) is wasteful and introduces unnecessary "empty" logs. **Failure handling:** Alert on missing files by a certain deadline. Idempotent via filename hashing to avoid double-processing.

### **Pipeline 5: ML Feature Pipeline**

**Scheduling Strategy:** Dependency-aware. **Schedule/Trigger:** Success event from Pipeline 1\. **Justification:** Features must reflect the latest warehouse data. Running this on a fixed cron might result in features being built from "yesterday's" data if Pipeline 1 is delayed. **Failure handling:** Retry. If failed, the ML scoring job must be blocked to prevent inaccurate predictions.

### **Pipeline 6: Data Quality (DQ) Checks**

**Scheduling Strategy:** Dependency-aware. **Schedule/Trigger:** Completion of any upstream pipeline (1, 2, 3, 4, or 5). **Justification:** DQ is a "gatekeeper." It must run immediately after data changes to catch errors before consumers see them. **Failure handling:** Send high-priority Slack/Email alert.

---

## **Part 3: Anti-Pattern Identification**

### **Anti-Pattern 1: "Scheduling by Hope" (Hard-coded Time Gaps)**

**What's wrong:** Using fixed time intervals (1 AM, 2 AM, 3 AM) to manage dependencies. **Risk:** If the 1 AM job takes 65 minutes, the 2 AM job starts on incomplete data. **Fix:** Use a Workflow Orchestrator (Airflow, Dagster) to link jobs: `A >> B >> C`.

### **Anti-Pattern 2: "Tight-Loop Polling"**

**What's wrong:** Running a high-frequency cron (every 5 mins) to check for a low-frequency event (once per week). **Risk:** Unnecessary compute costs and "log pollution" making it hard to find actual errors. **Fix:** Use an event-based trigger (e.g., S3 Event Notifications or a Lambda trigger).

### **Anti-Pattern 3: "Resource Contention"**

**What's wrong:** Scheduling a warehouse refresh while the source database is busy with a backup. **Risk:** Increased lock contention on the source DB, potentially crashing the refresh or slowing down the backup. **Fix:** Schedule the refresh to start only after the backup success signal is received.

---

## **Part 4: Dependency DAG Design**

\[Pipeline 4: Partner Ingestion\] ──┐  
                                  │  
\[Pipeline 2: Clickstream\] ────────┤  
                                  │     ┌───→ \[Pipeline 6: Data Quality Checks\]  
\[Pipeline 1: Warehouse Refresh\] ──┼─────┤  
                                  │     └───→ \[Pipeline 5: ML Features\] ──→ \[ML Scoring\]  
\[Pipeline 3: Financial Close\] ────┘  
    (Step 1: Extract)   
           ↓  
    (Step 2: Validate)   
           ↓  
    (Step 3: Calculate)   
           ↓  
    (Step 4: Report)   
           ↓  
    (Step 5: Email)  
