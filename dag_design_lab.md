##  **Scenario 1 — Linear DAG (E-Commerce)**

The linear pattern is the most common starting point for data engineering. It enforces a strict "Hand-off" between tasks where data quality and completeness are paramount.

### **Failure Propagation Analysis**

* **Critical Failure:** If `extract_orders` fails, the entire pipeline stops. This is a **Hard Dependency**; you cannot clean data that doesn't exist.  
* **Downstream Impact:** A failure in `load_to_warehouse` means your processing was successful, but your "Last Mile" failed. The data is transformed and ready, but invisible to the end stakeholders.

---

## **Step 3: Scenario 2 — Parallel Fan-In DAG (Multi-Source)**

This pattern is designed for **Efficiency**. By running independent extractions in parallel, the total runtime of the pipeline is determined by the *longest single task* rather than the *sum of all tasks*.

### **Parallelism and Bottlenecks**

* **The "Longest Pole" Effect:** If the CRM extraction takes 30 minutes and Billing takes 2 minutes, the `merge_data` task must wait for the full 30 minutes.  
* **Resource Management:** While parallel tasks save time, they consume more concurrent "worker slots" in Airflow. Scaling your infrastructure to match your parallelism is key.

---

## **Step 4: Scenario 3 — Conditional Branching DAG (Data Quality)**

Branching introduces **Intelligence** to your pipeline. Instead of a "Pass/Fail" binary where a failure stops everything, branching allows for a "Graceful Handling" of bad data via a quarantine path.

### **Logic at Runtime**

Unlike parallel tasks that all execute, the `BranchPythonOperator` acts as a traffic controller.

* **Mutually Exclusive:** If the "Valid" path is chosen, Airflow explicitly marks the "Invalid" path tasks as **Skipped**. This is reflected in the UI with a pink color code.  
* **Data Safety:** This pattern prevents "Silent Failures" where bad data might have otherwise been loaded into a production warehouse.

| Aspect | Scenario 1 (Linear) | Scenario 2 (Fan-In) | Scenario 3 (Branching) |
| :---- | :---- | :---- | :---- |
| **Pattern** | Linear chain | Parallel fan-in | Conditional branching |
| **I/O Efficiency** | Low (Sequential) | **High (Concurrent)** | Moderate |
| **Complexity** | Low | Moderate | High |
| **Use Case** | Single source ETL | **Multi-source integration** | **Data Quality / Validation** |

