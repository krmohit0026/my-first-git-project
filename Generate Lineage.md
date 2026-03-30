## **Deliverable 1: Table-Level Lineage Graph**

The following map outlines the end-to-end dependency flow from raw ingestion to final consumers.

**Data Flow Architecture:**

1. **Sources (Bronze):** raw.user\_interactions, raw.partner\_events, raw.content\_catalog, raw.user\_profiles, raw.billing\_events.  
2. **Staging (Silver):** stg\_user\_interactions, stg\_partner\_events, stg\_billing\_events.  
3. **Intermediate (Silver+):** int\_enriched\_events, int\_user\_sessions, int\_combined\_revenue.  
4. **Marts (Gold):** fct\_user\_interactions, fct\_daily\_engagement, fct\_revenue, dim\_users, dim\_content.  
5. **Consumers (Platinum):** Tableau (Exec/Product/Partner Dashboards), ML Models (Churn/Rec), Slack Bot, Finance Extracts.

**Complete Dependency Map:**

* **User Path:** raw.user\_interactions → stg\_user\_interactions → int\_enriched\_events → fct\_daily\_engagement → rpt\_user\_churn → **ML: Churn Prediction**.  
* **Revenue Path:** (stg\_user\_interactions \+ stg\_partner\_events \+ stg\_billing\_events) → int\_combined\_revenue → fct\_revenue → rpt\_weekly\_revenue → **Tableau: Executive Dashboard**.  
* **Content Path:** raw.content\_catalog → dim\_content → int\_enriched\_events → fct\_content\_performance → **Tableau: Partner Report**.

---

## **Deliverable 2: Column-Level Lineage**

Detailed traces for the three core metrics:

## **A. fct\_revenue.total\_revenue**

* **Source 1:** raw.user\_interactions.amount (where action='purchase') → stg\_user\_interactions.amount (CAST to Decimal) → int\_combined\_revenue.  
* **Source 2:** raw.partner\_events.amount → stg\_partner\_events.revenue\_usd (Multiplied by exchange rate) → int\_combined\_revenue.  
* **Source 3:** raw.billing\_events.amount → stg\_billing\_events.amount\_usd → int\_combined\_revenue.  
* **Target:** SUM(amount) in fct\_revenue.

## **B. fct\_daily\_engagement.engagement\_score**

* **Source:** raw.user\_interactions.action.  
* **Logic Trace:** raw.user\_interactions.action → stg\_user\_interactions (LOWER/Clean) → int\_enriched\_events.  
* **Formula:** (play\_count \+ 2\*like\_count \+ 3\*share\_count \- skip\_count) / total \* 100.

## **C. rpt\_weekly\_revenue.active\_users**

* **Source:** raw.user\_interactions.user\_id.  
* **Logic Trace:** stg\_user\_interactions.user\_id → int\_enriched\_events → fct\_daily\_engagement (Grain: 1 row per user/day).  
* **Final Aggregation:** COUNT(DISTINCT user\_id) filtered by date\_key in rpt\_weekly\_revenue.

---

## **Deliverable 3: Impact Analysis**

| Change Scenario | Risk Level | Affected Models | Migration/Mitigation Plan |
| :---- | :---- | :---- | :---- |
| **1\. Add "save" action** | **Low** | stg\_user\_interactions, fct\_daily\_engagement | Add "save" to the CASE statement in the engagement score formula to give it a weight. |
| **2\. Drop "country" column** | **High** | stg\_user\_interactions, rpt\_user\_churn, **ML Churn Model** | **Warning:** This breaks the ML feature store. Must update stg\_user\_interactions to join dim\_users to recover country data before dropping raw column. |
| **3\. Decimal (10,2) to (12,4)** | **Medium** | All Staging/Fact revenue models | Update all CAST operations in the lineage. Perform a data audit to ensure no breakage in UNION ALL operations in int\_combined\_revenue. |

---

## **Deliverable 4: Lineage Documentation (YAML)**

YAML

\# lineage\_documentation.yml  
models:  
  \- name: fct\_daily\_engagement  
    description: "Daily engagement metrics per user."  
    upstream:  
      direct: \[int\_enriched\_events, dim\_dates\]  
      indirect: \[stg\_user\_interactions, raw.user\_interactions\]  
    columns:  
      \- name: engagement\_score  
        meta:  
          lineage:  
            sources: \[raw.user\_interactions.action\]  
            transformations: \[LOWER, weighted\_sum\_formula\]  
  \- name: fct\_revenue  
    description: "Consolidated revenue fact table."  
    upstream:  
      direct: \[int\_combined\_revenue, dim\_dates\]  
    downstream:  
      dashboards: \[Executive Dashboard\]  
      reports: \[rpt\_weekly\_revenue\]

---

## **Deliverable 5: Reflection Answers**

1. **Which metric had the most complex lineage?**  
   fct\_revenue.total\_revenue. It is a **convergent lineage** that pulls from three distinct source systems (Kafka, SFTP, and Batch), requiring normalization and currency conversion before unioning.  
2. **Which proposed change had the highest risk? Why?**  
   **Dropping the "country" column.** It is a destructive change. Because it is used in the **ML Churn Prediction Model**, dropping it without a migration plan would cause the model training pipeline to fail, impacting business predictions.  
3. **How would you keep lineage documentation up to date?**  
   By using **dbt-docs** and embedding metadata within the .yml files. By treating documentation as code, every Pull Request (PR) must include updated lineage descriptions, ensuring the documentation evolves with the SQL logic.  
4. **What tools would you use to automate lineage collection?**  
   * **dbt Core/Cloud** for transformation lineage.  
   * **Monte Carlo** or **DataFold** for automated impact analysis.  
   * **OpenLineage** for cross-platform tracing (from Airflow to Snowflake).

