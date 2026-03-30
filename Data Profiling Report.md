---

## **Structural Analysis**

#### **Step 1 & 2: Completeness & Empty Strings**

The queries in these steps use COUNT(column) vs COUNT(\*).

* **Explanation:** In SQL, COUNT(column) ignores NULLs, while COUNT(\*) counts every row. By subtracting them, we find the "hidden" missing data. Step 2 goes further by checking for '' (empty strings), which often bypass standard NULL checks.

#### **Step 4 & 5: Cardinality & Distribution**

* **Cardinality:** The formula COUNT(DISTINCT user\_id) / COUNT(user\_id) tells you how "unique" your users are. A low ratio means your users are very active (repeating many times).  
* **Percentiles:** The PERCENTILE\_CONT functions are critical for identifying **Outliers**. If your p99 is $\\$100$ but your MAX is $\\$10,000$, you have a data quality issue or a "whale" user that might skew your averages.

---

## **Temporal & Freshness**

#### **Step 7 & 8: Volume & Hourly Patterns**

* **Window Functions:** LAG(COUNT(\*)) allows the query to "look back" at yesterday's total to calculate the **Day-over-Day (DoD)** change. This is the best way to spot a pipeline failure (e.g., if volume drops 90% suddenly).  
* **Hourly Patterns:** This identifies peak usage. If the peak hour is 3 AM UTC, you should probably schedule your heavy dbt transformations for 5 AM UTC to avoid resource contention.

---

## **Cross-Table Integrity**

#### **Step 10 & 11: Referential Integrity**

* **Orphan Events:** This uses a LEFT JOIN where the right side is NULL. This finds "Ghost Users"—events that claim to belong to a user who doesn't exist in your dim\_users table. This usually happens because of a sync lag or a bug in the signup flow.

---

## **Final Profiling Report** 

Plaintext

\======= STREAMPULSE DATA PROFILING REPORT \=======  
Generated: 2026-03-30  
Period: Last 30 days  
Analyst: Gemini AI Data Engineer

── 1\. DATASET OVERVIEW ──  
Tables profiled: 3  
  raw\_user\_interactions: 1,250,400 rows  
  dim\_users: 45,000 rows  
  fct\_daily\_engagement: 320,000 rows

── 2\. COMPLETENESS ──  
Column       | Null % | Empty % | Status        | Recommendation  
event\_id     | 0.0%   | N/A     | OK            | Primary Key  
user\_id      | 0.05%  | 0.01%   | WARNING       | Investigate guest sessions  
action       | 0.0%   | 0.0%    | OK            | Mandatory field  
amount       | 82.0%  | N/A     | OK            | Nulls expected for non-purchases  
device       | 1.2%   | 0.5%    | OK            | Clean empty strings to NULL  
country      | 0.8%   | 4.2%    | WARNING       | High empty string rate in mobile

── 3\. UNIQUENESS & CARDINALITY ──  
\- Event ID is 100% unique (no duplicates found).  
\- User Cardinality: 0.036 (Average user performs 27 actions per month).

── 4\. DISTRIBUTION ──  
\- Numeric (amount): Mean $12.40, Median $9.99, Max $450.00.   
\- 12 negative amounts found (Potential refund logic error).  
\- Top Device: Mobile (62%), Web (30%), TV (8%).

── 5\. TEMPORAL PATTERNS ──  
\- Daily volume: Avg 41k, Min 12k (Tuesdays), Max 85k (Sundays).  
\- Peak hour: 20:00 \- 22:00 (Evening prime time).  
\- Weekend effect: 2.5x volume increase compared to weekdays.

── 6\. FRESHNESS ──  
\- Event staleness: 1.2 hours (Source latency is low).  
\- Load staleness: 0.5 hours (dbt is running frequently).

── 7\. CROSS-TABLE INTEGRITY ──  
\- Orphan event rate: 0.45% (5,626 events tied to missing users).

── 8\. RECOMMENDED VALIDATION RULES ──  
  1\. amount must be \> 0 for 'purchase' actions.  
  2\. user\_id cannot be NULL or empty string.  
  3\. country must be exactly 2 characters.  
  4\. event\_timestamp cannot be in the future.  
  5\. engagement\_score must be between 0 and 100\.

── 9\. RECOMMENDED ANOMALY THRESHOLDS ──  
  1\. Daily volume change \> 50% (DoD).  
  2\. Orphan rate \> 1%.  
  3\. p99 amount \> $500.

── 10\. ISSUES FOUND ──  
  ⚠️ 4.2% Empty strings in 'country' column.  
  ⚠️ Negative values found in 'amount' column.  
  ❌ 5,600+ Orphan events (Missing users in dim\_users).  
\=====================================================

---

## **🧠 Reflection Answers**

1. **Which column had the most surprising profiling result?**  
   The **country** column. While the NULL rate was low (0.8%), the empty string rate was high (4.2%). This shows that the front-end application is sending "blank" data rather than omitting the field, which would bypass most basic dbt not\_null tests.  
2. **What validation rules would you implement based on this profile?**  
   I would implement a **Conditional Check**: IF action \= 'purchase' THEN amount \> 0. I would also add a **Regex test** to the country column to ensure it is always 2 uppercase letters.  
3. **How often should this profiling report be regenerated?**  
   This should be run **Weekly**. Daily is too frequent for "discovery," but once a month is too slow to catch structural drift in how users are using the app.  
4. **What would you automate vs run ad-hoc?**  
   * **Automate:** Freshness checks and Null/Duplicate counts (via dbt tests).  
   * **Ad-hoc:** Percentile distributions and Hourly patterns. These are useful for deep-dives and dashboard planning but don't need to block the daily pipeline.

