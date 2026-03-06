### **Part 1: Failure Scenario Analysis**

### **Scenario 2: Database Connection Timeout**

**Classification:** Transient

**Reasoning:** The error is "Operational," caused by a brief maintenance window (5–10 mins). Since the cluster auto-recovers, retrying after the maintenance concludes will succeed.

**Retry Configuration:**

* retries: 3  
* retry\_delay: timedelta(minutes=5)  
* retry\_exponential\_backoff: True  
* max\_retry\_delay: timedelta(minutes=20) **Alert Configuration:**  
* Severity: P2 (if exhausted)  
* Channel: PagerDuty / Slack \#data-alerts  
* When to alert: After all retries exhausted.  
* Message template: "Load\_to\_warehouse failed: Redshift connection timeout. Cluster may be down for extended maintenance."  
  **Runbook:**  
1. Check AWS Console for Redshift cluster status (Available, Modifying, or Rebooting).  
2. Review concurrent WLM (Workload Management) queries to see if a massive "vacuum" or "analyze" is locking the cluster.  
3. Attempt to connect via Query Editor to verify manual connectivity.  
4. If cluster is healthy, manually restart the task.

### **Scenario 3: Invalid Data Schema (Missing Column)**

**Classification:** Permanent

**Reasoning:** A missing column in a source file is a structural change. No amount of waiting or retrying will make the partner's file "grow" the missing column.

**Retry Configuration:**

* retries: 0  
* retry\_delay: N/A  
* retry\_exponential\_backoff: False  
* max\_retry\_delay: N/A **Alert Configuration:**  
* Severity: P1  
* Channel: PagerDuty \+ Slack \#data-incidents  
* When to alert: Immediately on first failure.  
* Message template: "CRITICAL: Schema mismatch in validate\_partner\_data. Column 'transaction\_amount' missing. Downstream finance reports blocked."  
  **Runbook:**  
1. Download the failing CSV from the landing zone.  
2. Confirm the header row is missing the expected column.  
3. Contact the Partner's Technical Lead to identify why the export format changed.  
4. Decide: Either rollback the pipeline to an older schema or wait for a corrected file from the partner.

### **Scenario 4: S3 Bucket Permission Denied**

**Classification:** Permanent

**Reasoning:** An "AccessDenied" (403) error is a security policy issue. Retrying is useless until a Cloud Admin manually fixes the IAM policy.

**Retry Configuration:**

* retries: 0  
* retry\_delay: N/A  
* retry\_exponential\_backoff: False  
* max\_retry\_delay: N/A **Alert Configuration:**  
* Severity: P2  
* Channel: Slack \#data-alerts \+ Jira Ticket  
* When to alert: Immediately.  
* Message template: "Permission Error: archive\_processed\_files cannot write to S3. IAM Role permissions likely revoked."  
  **Runbook:**  
1. Identify the IAM Role used by the Airflow Task.  
2. Check the IAM Policy for `s3:PutObject` permissions on the specific archive bucket.  
3. Contact the Security Team to see if the audit policy can be reverted.  
4. Once permissions are restored, clear the task to resume the archive.

### **Scenario 5: Network Partition (Intermittent Connectivity)**

**Classification:** Transient

**Reasoning:** The network team confirmed routing issues that self-resolve. Intermittent "Connection Resets" are the definition of a retryable network blip.

**Retry Configuration:**

* retries: 5  
* retry\_delay: timedelta(minutes=5)  
* retry\_exponential\_backoff: True  
* max\_retry\_delay: timedelta(minutes=30) **Alert Configuration:**  
* Severity: P3  
* Channel: Slack \#data-alerts  
* When to alert: Only after all 5 retries fail.  
* Message template: "Sync\_to\_datalake failed after 5 retries. Persistent network instability between On-Prem and AWS."  
  **Runbook:**  
1. Check VPN/DirectConnect status between data center and AWS.  
2. Check AWS Service Health Dashboard for S3 regional issues.  
3. Ping the S3 endpoint from the on-prem server to check for packet loss.  
4. If network is restored, restart the sync.

### **Scenario 6: Data Quality Check Fails (Excessive Nulls)**

**Classification:** Permanent

**Reasoning:** The pipeline worked perfectly; the data is "garbage in, garbage out." Retrying a query on the same static table will result in the same 35% null rate.

**Retry Configuration:**

* retries: 0  
* retry\_delay: N/A  
* retry\_exponential\_backoff: False  
* max\_retry\_delay: N/A **Alert Configuration:**  
* Severity: P1 (due to marketing impact)  
* Channel: PagerDuty \+ Slack \#data-incidents  
* When to alert: Immediately.  
* Message template: "DQ FAILURE: 'email' column null rate @ 35.2% (Threshold 10%). Marketing campaigns potentially affected."  
  **Runbook:**  
1. Query the warehouse to find the `created_at` date where nulls began to spike.  
2. Trace back to the source system (Customer DB) to check if the email field is being populated.  
3. Inform the Marketing Team that today's audience list is incomplete.  
4. Once source system is fixed, re-run the extraction for the affected dates.

---

## **Part 2: Company Default Retry Policy**

## This policy should be implemented in your Airflow `default_args` (or equivalent orchestrator settings) to ensure that every task has a safety net without manual configuration.

### `default_args` Configuration

from datetime import timedelta

default\_args \= {  
    "owner": "data\_engineering",  
    "retries": 3,  
    "retry\_delay": timedelta(minutes=5),  
    "retry\_exponential\_backoff": True,  
    "max\_retry\_delay": timedelta(minutes=60),  
    "depends\_on\_past": False,  
    "email\_on\_failure": True,  
}  
**Justification**

| Parameter | Value | Why |
| :---- | :---- | :---- |
| **retries** | **3** | Provides enough attempts to bypass 90% of transient network or "blip" issues without letting a failing job run forever. |
| **retry\_delay** | **5 min** | 5 minutes is the "Goldilocks" zone—long enough for a quick DB reboot or DNS refresh, but short enough to avoid missing most hourly SLAs. |
| **exponential\_backoff** | **True** | Essential for preventing a "thundering herd" effect. If an API is struggling, backing off (5m, 10m, 20m) gives the remote system breathing room to recover. |
| **max\_retry\_delay** | **60 min** | Caps the wait time. Without this, exponential backoff can lead to tasks waiting 12+ hours between tries, which is usually unacceptable for production. |

### 

---

### **Override Guidelines**

### 

| Scenario | Recommended Override | Reason |
| :---- | :---- | :---- |
| **Known Permanent Failures** | retries: 0 | If you know a specific check (like a schema check) is binary, don't waste compute credits retrying. |
| **Heavy API Usage** | retry\_delay: 2 min | For APIs with strict 60-second windows (like Scenario 1), a shorter initial delay is better. |
| **Critical Financial Path** | retries: 5 | For the "Crown Jewel" pipelines, add extra retries to exhaust every possibility of auto-recovery. |
| **Sensors / Waiting** | retries: 10+ | For tasks waiting on external files, high retries with long delays are appropriate. |

## **Part 3: Alert Priority Matrix (P1–P4)**

### 

| Priority | Name | Criteria | Response Time | Channel | Escalation |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **P1** | **Critical** | Revenue impacting, data loss risk, or external customer data is stale. | **\< 15 min** | PagerDuty (Phone) \+ Slack \#data-incidents | If unacknowledged in 15m → Page Manager. |
| **P2** | **High** | Internal SLA breach (\>2hrs stale) or failure after all retries exhausted. | **\< 1 hour** | PagerDuty (Push) \+ Slack \#data-alerts | If unresolved in 2h → Notify Team Lead. |
| **P3** | **Medium** | Non-critical delays, data quality warnings (near threshold), or expected transient failures. | **\< 4 hours** | Slack \#data-alerts | If recurring 3+ times/week → Escalate to P2. |
| **P4** | **Low** | Successful recovery after retries, minor performance lag, or info logs. | **Next Biz Day** | Email Digest / Slack (no @channel) | None. |

### **Scenario-to-Priority Mapping**

### 

| Scenario | Priority | Justification |
| :---- | :---- | :---- |
| **1\. API Rate Limit** | **P3** | Highly transient. Backoff usually handles it. Only needs attention if it fails all 3 tries. |
| **2\. DB Timeout** | **P2** | Indicates the Warehouse is under stress. If it fails 3 times, an admin needs to check Redshift's health. |
| **3\. Invalid Schema** | **P1** | Permanent and catastrophic for downstream. Requires immediate human intervention with the partner. |
| **4\. S3 Permission** | **P2** | Blocks the "cleanup" of the pipeline. Not revenue-impacting yet, but will cause storage bloat/confusion. |
| **5\. Network Partition** | **P3** | Standard infrastructure "noise." Only alert if the network stays down longer than the retry window. |
| **6\. Data Quality** | **P1** | Even though the pipeline "worked," the data is unusable for Marketing. This is a "Silent Failure" risk. |

### 

