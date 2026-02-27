## **Part 1: Failure Scenario Analysis**

### **Scenario 2: Database Connection Timeout**

**Classification:** Transient

**Reasoning:** Connection timeouts are usually caused by temporary network congestion or resource contention. Since Redshift auto-recovers from maintenance within minutes, the system will eventually be available.

**Retry Configuration:**

* **retries:** 3  
* **retry\_delay:** `timedelta(minutes=5)`  
* **retry\_exponential\_backoff:** True  
* **max\_retry\_delay:** `timedelta(minutes=15)`  
  **Alert Configuration:**  
* **Severity:** P2 (High)  
* **Channel:** PagerDuty \+ Slack \#data-alerts  
* **When to alert:** After ALL 3 retries are exhausted.  
* **Message template:** "Redshift load failed after 3 attempts. Potential cluster overload or extended maintenance window. Check AWS Health Dashboard."  
  **Runbook:**  
1. Check CloudWatch metrics for Redshift (CPU, Disk Space, Concurrent Queries).  
2. Verify if any massive vacuuming or maintenance operations are scheduled.  
3. Check the AWS Health Dashboard for regional Redshift issues.  
4. Manually test the connection using a SQL client; if successful, restart the DAG.

---

### **Scenario 3: Invalid Data Schema (Missing Column)**

**Classification:** Permanent

**Reasoning:** A missing column in a CSV is a code/contract change. No amount of retrying will make the partner's file "spawn" the missing column.

**Retry Configuration:**

* **retries:** 0 (Fail fast)  
* **retry\_delay:** N/A  
* **retry\_exponential\_backoff:** N/A  
  **Alert Configuration:**  
* **Severity:** P1 (Critical)  
* **Channel:** PagerDuty \+ Slack \#data-incidents  
* **When to alert:** Immediately.  
* **Message template:** "CRITICAL: Schema mismatch in partner data. Column 'transaction\_amount' missing. Downstream financial reporting at risk."  
  **Runbook:**  
1. Download the failing CSV from the landing zone and verify columns.  
2. Contact the partner's technical contact immediately regarding the format change.  
3. Check internal documentation for recent contract updates.  
4. If the column is intentionally removed, update the DAG and schema definitions.

---

### **Scenario 4: S3 Bucket Permission Denied**

**Classification:** Permanent

**Reasoning:** Permission errors are authorization issues. Retrying against a 403 Access Denied error only generates unnecessary logs until the IAM policy is fixed.

**Retry Configuration:**

* **retries:** 0  
* **retry\_delay:** N/A  
  **Alert Configuration:**  
* **Severity:** P2 (High)  
* **Channel:** Slack \#data-alerts \+ Jira  
* **When to alert:** Immediately.  
* **Message template:** "IAM Access Denied for S3 archive bucket. Verify Service Account permissions."  
  **Runbook:**  
1. Check the IAM Role attached to the Airflow worker.  
2. Cross-reference the S3 Bucket Policy for the archive bucket.  
3. Contact the Security/DevOps team to check for recent "IAM Policy Drift" or audit removals.  
4. Once permissions are restored, clear the task to re-run.

---

### **Scenario 5: Network Partition**

**Classification:** Transient

**Reasoning:** Intermittent routing issues are common in hybrid-cloud setups and typically self-resolve once BGP or internal routing tables update.

**Retry Configuration:**

* **retries:** 4  
* **retry\_delay:** `timedelta(minutes=4)`  
* **retry\_exponential\_backoff:** True  
* **max\_retry\_delay:** `timedelta(minutes=20)`  
  **Alert Configuration:**  
* **Severity:** P3 (Medium)  
* **Channel:** Slack \#data-alerts  
* **When to alert:** After 2 failed attempts (early warning) and final failure.  
* **Message template:** "Intermittent network failure between On-Prem and AWS. Attempting retry."  
  **Runbook:**  
1. Run a `traceroute` or `ping` from the worker node to the S3 endpoint.  
2. Check the on-prem firewall logs for dropped packets.  
3. Confirm with the Network team if there is a known ISP outage.  
4. Verify S3 file integrity upon successful retry.

---

### **Scenario 6: Data Quality Check Fails (Excessive Nulls)**

**Classification:** Permanent (at the pipeline level)

**Reasoning:** The pipeline functioned correctly, but the data is "garbage." Retrying the SQL query on the same static table will always yield the same 35% null rate.

**Retry Configuration:**

* **retries:** 0  
  **Alert Configuration:**  
* **Severity:** P1 (Critical)  
* **Channel:** PagerDuty \+ Slack \#data-incidents  
* **When to alert:** Immediately.  
* **Message template:** "DQ FAILURE: 'email' column null rate @ 35%. Likely upstream bug in source system."  
  **Runbook:**  
1. Run a profiling query to find when the nulls started appearing.  
2. Trace the data back to the source system API/DB.  
3. Contact the product team responsible for the customer signup flow.  
4. Do not allow downstream marketing DAGs to run until data is remediated.

---

## **Part 2: Company Default Retry Policy**

We use a "Resilient Default" strategy. We assume failures are transient unless proven otherwise, but we cap the retries to avoid "zombie tasks" that run for days.

### **default\_args Configuration**

default\_args \= {  
    "retries": 3,  
    "retry\_delay": timedelta(minutes=5),  
    "retry\_exponential\_backoff": True,  
    "max\_retry\_delay": timedelta(minutes=60),  
}

| Parameter | Value | Why |
| :---- | :---- | :---- |
| **retries** | 3 | Covers the "Rule of Three": first blip, second confirmation, third final attempt. |
| **retry\_delay** | 5m | Gives short maintenance windows or network resets enough time to stabilize. |
| **backoff** | True | Reduces "Thundering Herd" effect on downstream databases and APIs. |
| **max\_delay** | 60m | Ensures that even with backoff, we don't wait 10+ hours for a single task retry. |

Part 3: Alert Priority Matrix

| Priority | Name | Criteria | Response Time | Channel | Escalation | Examples |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| **P1** | **Critical** | Revenue/Compliance impact; Data loss; Customer facing. | \< 15 min | PagerDuty (Call) | Manager (15m) | Missing Finance Column; 35% Nulls |
| **P2** | **High** | Internal SLA breach; Permanent failure; Final retry failed. | \< 1 hr | PagerDuty (Push) | Team Lead (2h) | S3 Access Denied; Redshift Timeout |
| **P3** | **Medium** | Transient delay; DQ warning; Performance dip. | \< 4 hr | Slack \#data-alerts | Weekly Review | API Rate Limit (429) |
| **P4** | **Low** | Self-resolved; Informational; Success after retry. | Next Bus. Day | Slack (Muted) | None | Network Blip (Recovered) |

Scenario-to-Priority Mapping

| Scenario | Priority | Justification |
| :---- | :---- | :---- |
| 1\. API Rate Limit | **P3** | Common and self-resolving; only a risk if it happens constantly. |
| 2\. DB Timeout | **P2** | Indicates warehouse pressure; needs investigation into concurrent jobs. |
| 3\. Invalid Schema | **P1** | Stops all financial reporting; requires immediate partner intervention. |
| 4\. S3 Permission | **P2** | Permanent blockade; requires manual admin fix but no data is lost. |
| 5\. Network Partition | **P3** | Transient and usually brief; impact is limited to latency. |
| 6\. DQ (Nulls) | **P1** | Prevents marketing from sending emails; impacts customer experience. |

