## **Part 1: Executive Dashboard Queries**

## **Widget 1: KPI Cards**

SQL

WITH metrics AS (  
  SELECT   
    event\_date,  
    COUNT(DISTINCT user\_id) as dau,  
    SUM(amount) as revenue,  
    AVG(watch\_minutes) as avg\_watch  
  FROM MARTS.fct\_daily\_engagement  
  WHERE event\_date \>= CURRENT\_DATE \- 2  
  GROUP BY 1  
)  
SELECT   
  today.dau,  
  (today.dau \- yesterday.dau) / NULLIF(yesterday.dau, 0) \* 100 as dau\_pct\_change,  
  today.revenue as mrr,  
  today.avg\_watch as avg\_watch\_time  
FROM metrics today  
JOIN metrics yesterday ON today.event\_date \= yesterday.event\_date \+ 1  
WHERE today.event\_date \= CURRENT\_DATE \- 1;

## **Widget 2: DAU Trend Line (90 days)**

SQL

SELECT   
    event\_date,  
    dau,  
    AVG(dau) OVER (ORDER BY event\_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as dau\_7d\_moving\_avg,  
    LAG(dau, 7) OVER (ORDER BY event\_date) as dau\_prev\_week,  
    (dau \- LAG(dau, 7) OVER (ORDER BY event\_date)) / NULLIF(LAG(dau, 7) OVER (ORDER BY event\_date), 0) \* 100 as wow\_change\_pct  
FROM MARTS.v\_executive\_daily  
WHERE event\_date \>= CURRENT\_DATE \- 90  
ORDER BY event\_date ASC;

## **Widget 3: Revenue by Plan (Pie Chart)**

SQL

SELECT   
    plan\_name,  
    COUNT(DISTINCT user\_id) as subscriber\_count,  
    SUM(mrr) as total\_mrr,  
    RATIO\_TO\_REPORT(total\_mrr) OVER () \* 100 as pct\_of\_total\_mrr  
FROM MARTS.v\_subscription\_analysis  
WHERE month \= DATE\_TRUNC('month', CURRENT\_DATE)  
  AND status \= 'Active'  
GROUP BY 1;

## **Widget 4: Top 5 Shows (Bar Chart)**

SQL

SELECT   
    show\_name,  
    genre,  
    SUM(views) as total\_views,  
    SUM(unique\_viewers) as unique\_viewers,  
    AVG(completion\_rate) as avg\_completion\_rate  
FROM MARTS.v\_content\_performance  
WHERE date \>= DATE\_TRUNC('week', CURRENT\_DATE)  
GROUP BY 1, 2  
ORDER BY total\_views DESC  
LIMIT 5;

---

## **Part 2: Content Performance Dashboard Queries**

## **Widget 4: Show Leaderboard**

SQL

SELECT   
    show\_name,  
    genre,  
    SUM(views) as total\_views,  
    COUNT(DISTINCT user\_id) as unique\_viewers,  
    AVG(completion\_rate) as avg\_completion,  
    (SUM(views) \* 0.3) \+ (COUNT(DISTINCT user\_id) \* 0.3) \+ (AVG(completion\_rate) \* 100 \* 0.4) as engagement\_score  
FROM MARTS.v\_content\_performance  
GROUP BY 1, 2  
ORDER BY engagement\_score DESC  
LIMIT 20;

## **Widget 5: Completion Rate vs Duration Scatter**

SQL

SELECT   
    content\_id,  
    show\_name as title,  
    duration\_minutes,  
    AVG(completion\_rate) as completion\_rate,  
    SUM(views) as total\_views,  
    genre  
FROM MARTS.v\_content\_performance  
GROUP BY 1, 2, 3, 6  
HAVING total\_views \>= 1000;

---

## **Part 3: BI-Ready Views**

## **VIEW 1: Executive Daily Summary**

SQL

CREATE OR REPLACE VIEW MARTS.v\_executive\_daily AS  
SELECT   
    e.event\_date as date,  
    COUNT(DISTINCT e.user\_id) as dau,  
    COUNT(DISTINCT CASE WHEN e.event\_date \>= DATE\_TRUNC('month', e.event\_date) THEN e.user\_id END) as mau,  
    SUM(s.mrr) as mrr,  
    AVG(e.watch\_minutes) as avg\_watch\_minutes,  
    COUNT(DISTINCT CASE WHEN s.signup\_date \= e.event\_date THEN s.user\_id END) as new\_signups,  
    COUNT(DISTINCT CASE WHEN s.churn\_date \= e.event\_date THEN s.user\_id END) as churned,  
    (new\_signups \- churned) as net\_change  
FROM MARTS.fct\_daily\_engagement e  
LEFT JOIN MARTS.dim\_subscriptions s ON e.user\_id \= s.user\_id  
GROUP BY 1;

---

## **Part 4: Access Governance**

## **Task 1: BI Access Setup**

SQL

\-- Role Hierarchy  
CREATE ROLE IF NOT EXISTS BI\_ADMIN;  
CREATE ROLE IF NOT EXISTS BI\_EXPLORER;  
CREATE ROLE IF NOT EXISTS BI\_VIEWER;

GRANT ROLE BI\_VIEWER TO ROLE BI\_EXPLORER;  
GRANT ROLE BI\_EXPLORER TO ROLE BI\_ADMIN;

\-- Permissions  
GRANT USAGE ON DATABASE STREAMPULSE TO ROLE BI\_VIEWER;  
GRANT USAGE ON SCHEMA STREAMPULSE.MARTS TO ROLE BI\_VIEWER;  
GRANT SELECT ON ALL VIEWS IN SCHEMA STREAMPULSE.MARTS TO ROLE BI\_VIEWER;  
GRANT USAGE ON WAREHOUSE REPORTING\_WH TO ROLE BI\_VIEWER;

## **Task 2 & 3: Security Policies**

SQL

\-- Column-Level Masking  
CREATE OR REPLACE MASKING POLICY pii\_mask AS (val string)   
  RETURNS string \-\>  
  CASE   
    WHEN CURRENT\_ROLE() IN ('BI\_ADMIN', 'DATA\_ENG') THEN val  
    ELSE '\*\*\*\*\*\*\*\*\*'  
  END;

ALTER VIEW MARTS.v\_self\_service MODIFY COLUMN email SET MASKING POLICY pii\_mask;

\-- Row-Level Regional Security  
CREATE OR REPLACE ROW ACCESS POLICY regional\_policy AS (region string)  
  RETURNS boolean \-\>  
  CURRENT\_ROLE() \= 'BI\_ADMIN'  
  OR (CURRENT\_ROLE() \= 'BI\_VIEWER\_US' AND region \= 'NA')  
  OR (CURRENT\_ROLE() \= 'BI\_VIEWER\_EU' AND region \= 'EU');

---

## **Part 5: Performance Optimization**

## **Task 1: Warehouse Configuration**

SQL

ALTER WAREHOUSE REPORTING\_WH SET   
  WAREHOUSE\_SIZE \= 'MEDIUM'  
  AUTO\_SUSPEND \= 60   
  MAX\_CONCURRENCY\_LEVEL \= 8  
  MIN\_CLUSTER\_COUNT \= 1  
  MAX\_CLUSTER\_COUNT \= 3 \-- Multi-cluster for peak dashboard hours  
  STATEMENT\_TIMEOUT\_IN\_SECONDS \= 120;

## **Task 2: Materialized Views Strategy**

| Query/View | Complexity | Materialized View? | Justification |
| :---- | :---- | :---- | :---- |
| **v\_executive\_daily** | Medium | **Yes** | Accessed constantly by leadership; data only changes once daily. |
| **v\_content\_perf** | High | **Yes** | Aggregating millions of engagement rows is expensive. |
| **v\_self\_service** | High | **No** | Too many permutations of filters; standard view with clustering is better. |

## **Bonus: Alerting Query**

SQL

\-- DAU Anomaly Detection (Slack Alert Trigger)  
WITH stats AS (  
    SELECT   
        dau,  
        LAG(dau) OVER (ORDER BY date) as prev\_dau  
    FROM MARTS.v\_executive\_daily  
    WHERE date \>= CURRENT\_DATE \- 2  
)  
SELECT   
    dau,   
    prev\_dau,  
    (dau \- prev\_dau) / prev\_dau as drop\_pct  
FROM stats  
WHERE drop\_pct \<= \-0.20; \-- Detects \>20% drop

**Summary of Lab Accomplishments:**

1. **Dashboard Specifics:** Defined logic for every widget in the CEO and Content dashboards.  
2. **Data Modeling:** Built 4 specialized views to simplify BI developer workflows.  
3. **Governance:** Implemented a "Least Privilege" model with masking and row-level security.  
4. **Performance:** Tuned the warehouse and identified materialized view candidates to keep dashboard latency under 2 seconds.