## **Module: M14 – Advanced Orchestration**

Sensors are the "eyes" of an Airflow pipeline, allowing workflows to synchronize with the messy, unpredictable reality of external systems. This document outlines the strategic design for four common synchronization challenges.

---

## **Step 2: Scenario 1 — FileSensor for Partner Data**

### **Analysis**

* **Waiting for:** A physical file (`transactions.csv`) on a shared drive.  
* **Wait Duration:** Long (2–5 hours). Since the file can arrive anytime in a 5-hour window, the sensor may wait significantly.  
* **Condition Failure:** If the file is missing after 2 hours, the pipeline should fail and alert the team to contact the partner.  
* **Polling Frequency:** Low. Checking every few minutes is sufficient; sub-second latency is not required for a daily batch file.

### **Sensor Configuration**

wait\_for\_partner\_file \= FileSensor(  
    task\_id="wait\_for\_partner\_file",  
    filepath="/data/partner/{{ ds }}/transactions.csv",  
    poke\_interval=300,       \# 5 minutes  
    timeout=7200,            \# 2 hours  
    mode="reschedule",       \# Release worker slot  
    soft\_fail=False,         \# Fail and alert  
    dag=dag,  
)

Parameter Justification

| Parameter | Value | Justification |
| :---- | :---- | :---- |
| filepath | /data/partner/{{ ds }}/... | Uses {{ ds }} to remain idempotent; each DAG run only looks for the file matching its specific data interval. |
| poke\_interval | 300 | Balances system I/O load. Checking every 5 minutes is negligible for a filesystem but responsive enough for a daily batch. |
| mode | reschedule | **Critical choice.** Since the wait is hours, poke mode would waste a worker slot for the entire duration. reschedule allows other tasks to use that slot between checks. |

## **Step 3: Scenario 2 — ExternalTaskSensor for Cross-DAG Dependency**

### **Analysis**

* **Condition:** Success of the `final_load` task in the `warehouse_refresh` DAG.  
* **Schedule:** Both DAGs are synchronized at midnight.  
* **Failure:** If the upstream warehouse fails, the ML features should not be built, as they would be based on stale or incomplete data.

### **Sensor Configuration**

wait\_for\_warehouse \= ExternalTaskSensor(  
    task\_id="wait\_for\_warehouse\_refresh",  
    external\_dag\_id="warehouse\_refresh",  
    external\_task\_id="final\_load",  
    execution\_delta=timedelta(0),  
    poke\_interval=120,  
    timeout=10800,  
    mode="reschedule",  
    dag=dag,  
)

### **Failure Behavior**

* **Upstream Failure:** If `final_load` fails, the sensor will continue "poking" until it hits its 3-hour timeout. It will then fail. This prevents the ML pipeline from ever running on bad data.  
* **Misconfigured Delta:** If `execution_delta` is wrong, the sensor will look for a DAG run that doesn't exist, waiting until timeout.

---

## **Step 4: Scenario 3 — HttpSensor for API Health Check**

### **Analysis**

* **Condition:** Vendor API is online (HTTP 200\) and reporting a "healthy" status in the JSON body.  
* **Frequency:** High. Since maintenance windows are short, we want to start immediately after the API recovers.  
* **Wait Duration:** Short (expected \< 15 minutes).

### **Sensor Configuration**

wait\_for\_api \= HttpSensor(  
    task\_id="wait\_for\_vendor\_api",  
    endpoint="/health",  
    response\_check=lambda response: response.json().get("status") \== "healthy",  
    poke\_interval=60,  
    timeout=1800,  
    mode="poke", \# Short wait, keep the slot  
    dag=dag,  
)

Parameter Justification

| Parameter | Value | Justification |
| :---- | :---- | :---- |
| response\_check | Lambda | Ensures the API isn't just "up" but is actually ready for traffic. |
| mode | poke | Because maintenance is usually brief, the overhead of re-scheduling (shutting down the task and restarting it) might exceed the benefit of freeing the slot. |

## **Step 5: Scenario 4 — TimeSensor for Business Time Gate**

### **Analysis**

* **Condition:** The clock must strike 6:00 AM.  
* **Rule:** Hard business requirement to allow for manual adjustments.  
* **Timezone:** Critical factor; must match the business operational timezone.

### **Sensor Configuration**

from datetime import time as dt\_time

wait\_for\_business\_hours \= TimeSensor(  
    task\_id="wait\_for\_6am",  
    target\_time=dt\_time(6, 0, 0),  
    mode="reschedule",  
    timeout=14400,  
    dag=dag,  
)

### **Failure Behavior**

* **Past 6 AM:** If the DAG is triggered late (e.g., 7 AM), the sensor notices the condition is already met and succeeds instantly.  
* **Timezone Mismatch:** If the server is in UTC but the business is in EST, reports could be generated 5 hours early. Use `airflow.utils.timezone` to prevent this.

---

## **Step 6: Sensor Design Summary**

| \# | Scenario | Sensor Type | mode | poke\_interval | Key Risk |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 1 | Partner file upload | FileSensor | reschedule | 300s | Partner misses SLA |
| 2 | Cross-DAG | ExternalTaskSensor | reschedule | 120s | Upstream failure |
| 3 | API health | HttpSensor | poke | 60s | Vendor outage |
| 4 | Business gate | TimeSensor | reschedule | 60s | Timezone drift |

### **General Approach: Poke vs. Reschedule**

My decision between `poke` and `reschedule` is governed by the **Worker Slot Opportunity Cost**.

* **Use `poke`** for high-frequency, short-duration checks where the condition is likely to be met in minutes. This avoids the database overhead of constantly killing and rescheduling tasks.  
* **Use `reschedule`** for any wait longer than 5–10 minutes. This prevents "Sensor Deadlock," where all available Airflow workers are occupied by sensors doing nothing but sleeping, effectively freezing the rest of the pipeline.

