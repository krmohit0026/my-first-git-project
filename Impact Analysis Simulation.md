## **1\. Schema Change Assessment: Adding session\_id**

## **Impact Trace**

* **stg\_user\_interactions**: Add session\_id to the base SELECT statement. (Risk: **LOW**)  
* **int\_enriched\_events**: Propagate column. (Risk: **LOW**)  
* **int\_user\_sessions**: Logic review required. (Risk: **MEDIUM**)  
  * *Note:* This model currently derives sessions from timestamp gaps.  
* **fct\_daily\_engagement**: Add session-based aggregation (e.g., avg\_session\_duration). (Risk: **LOW**)  
* **Consumers**:  
  * **Tableau**: Update Revenue Dashboard to include session-level filtering.  
  * **ML Churn**: Feature engineering to include "Sessions per Week."

## **Deployment Plan**

1. **Source:** Execute ALTER TABLE raw.user\_interactions ADD COLUMN session\_id STRING;.  
2. **Staging:** Update stg\_user\_interactions.sql to include the new field.  
3. **Intermediate:** Update int\_user\_sessions to incorporate both the new ID and the legacy gap-logic for comparison.  
4. **Marts:** Update engagement models and run dbt build.  
5. **BI:** Update Tableau data source and verify visual consistency.

## **Decision on session\_id Approach**

**Choice: C) Run both in parallel, compare, then switch.**

**Justification:** Switching immediately (B) risks "breaking" historical trends if the technical session\_id differs from the previous 30-minute gap logic. By running both, we can quantify the variance and provide a "bridge" explanation to stakeholders before deprecating the old logic.

---

## **2\. Logic Change Assessment: Revenue Formula Update**

## **Full Impact Trace & Business Impact**

| Stakeholder | Current Value | New Value (Est.) | Delta | Business Impact |
| :---- | :---- | :---- | :---- | :---- |
| **CEO (Daily)** | $45,000 | $43,650 | \-3% | Perception of slight revenue drop. |
| **Finance (Weekly)** | $315,000 | $305,550 | \-$9,450 | Accurate reconciliation with bank records. |
| **Partners (Monthly)** | $12,000 | $11,640 | \-$360 | Partners receive payouts net of refunds. |
| **ML Models** | N/A | N/A | N/A | High risk of "drift" if models aren't retrained. |

## **Shadow Table Deployment Plan**

* **Phase 1 (Shadow):** Create fct\_daily\_engagement\_v2. Compare row-by-row for 7 days.  
* **Phase 2 (Validate):** Present the comparison report to Finance. Obtain written sign-off on the \-3% delta.  
* **Phase 3 (Switch):** Use dbt to swap the models. Rename v2 to the production name on a Monday morning.  
* **Phase 4 (Monitor):** Check access\_history to ensure all BI tools moved to the new model name.  
* **Rollback:** Revert the dbt alias or ref to the original table if discrepancies exceed 0.1%.

---

## **3\. Source Deprecation Plan: Legacy Billing**

## **60-Day Timeline**

* **Day 1-15:** Announce deprecation. Map columns. Stand up stg\_billing\_events (New).  
* **Day 16-30:** Parallel run. Perform SQL reconciliation (see below).  
* **Day 31-45 (Soft Deprecation):** Rename legacy table to legacy\_billing\_DEPRECATED. Revoke access for non-admin roles.  
* **Day 46-60 (Hard Deprecation):** Drop legacy table. Archive DDL in Git.

## **Migration Mapping**

| Legacy Column | New Column | Mapping Logic |
| :---- | :---- | :---- |
| billing\_id | transaction\_id | Direct move. |
| amount | amount\_cents | **New:** amount\_cents / 100.0 |
| status | payment\_status | Map 'paid' to 'completed'. |
| refund | refund\_amount | Use new dedicated field. |

---

## **4\. Stakeholder Notifications**

**Notification 1: Schema Change**

**To:** Product & Analytics Teams

**Subject:** \[Data Update\] New session\_id available in Marts

**Message:** We’ve added a native session\_id to our interactions data. For the next 30 days, we will provide both the new ID and the legacy "gap-calculated" sessions to ensure tracking consistency. Please use the new ID for all future session-level metrics.

**Notification 2: Logic Change**

**To:** Executive Team & Finance

**Subject:** \[Action Required\] Revenue Calculation Logic Update

**Message:** On **\[Date\]**, we will update the revenue metric to account for refunds. This will result in a \~3% decrease in reported revenue. This is a correction to ensure data accuracy. Please review the attached shadow-table comparison by **\[Date\]**.

**Notification 3: Deprecation**

**To:** All Data Users

**Subject:** \[Deprecation Notice\] Legacy Billing Table Retirement

**Message:** The raw.legacy\_billing table is being retired in 60 days. All data has been migrated to raw.billing\_events. Please update your ad-hoc queries using the provided mapping guide by **\[Date\]**.

---

## **5\. Reconciliation Queries (SQL)**

SQL

\-- Revenue Reconciliation: Legacy vs. New Source  
WITH legacy\_rev AS (  
    SELECT   
        DATE\_TRUNC('day', billing\_date) as dt,  
        SUM(amount) as total\_revenue  
    FROM raw.legacy\_billing  
    GROUP BY 1  
),  
new\_rev AS (  
    SELECT   
        DATE\_TRUNC('day', event\_timestamp) as dt,  
        SUM(amount\_cents / 100.0) as total\_revenue  
    FROM raw.billing\_events  
    GROUP BY 1  
)  
SELECT  
    COALESCE(l.dt, n.dt) as date,  
    l.total\_revenue as old\_rev,  
    n.total\_revenue as new\_rev,  
    ABS(l.total\_revenue \- n.total\_revenue) as delta,  
    (ABS(l.total\_revenue \- n.total\_revenue) / NULLIF(l.total\_revenue, 0)) \* 100 as delta\_pct  
FROM legacy\_rev l  
FULL OUTER JOIN new\_rev n ON l.dt \= n.dt  
WHERE delta\_pct \> 0.1; \-- Only show discrepancies above threshold

---

## **6\. Reflection Answers**

1. **Highest Risk Change:** The **Logic Change (Revenue)**. It is a "silent" change. If the code is wrong, the system still runs, but the company reports incorrect financial numbers, leading to legal or strategic errors.  
2. **Shadow Table Pattern:** It prevents the "silent change" problem by allowing side-by-side validation. You can prove the delta is exactly what was expected (e.g., \-3%) before it becomes the production source of truth.  
3. **Handling a 2% Delta:** Stop the migration immediately. A 2% delta (when 0.1% was expected) suggests a systemic error, such as missing timezone conversions or duplicate records in the new source.  
4. **Handling a Refusing Stakeholder:** Use a "Scream Test." Provide a migration script for them, but eventually rename the table to something like DEPRECATED\_ACCESS\_WILL\_BE\_REMOVED\_MAY\_1. If they still don't move, revoke access in Dev/Stage first to force the conversation.

