---

## **Step 1: Folder Structure**

Plaintext

cloudmetrics\_dbt/  
├── dbt\_project.yml  
├── README.md  
├── models/  
│   ├── staging/  
│   │   ├── \_sources.yml  
│   │   ├── schema.yml  
│   │   ├── stg\_users.sql  
│   │   ├── stg\_subscriptions.sql  
│   │   ├── stg\_events.sql  
│   │   ├── stg\_invoices.sql  
│   │   └── stg\_support\_tickets.sql  
│   ├── intermediate/  
│   │   ├── schema.yml  
│   │   ├── int\_users\_enriched.sql  
│   │   └── int\_support\_with\_users.sql  
│   └── marts/  
│       ├── schema.yml  
│       ├── mart\_user\_health.sql  
│       ├── mart\_revenue\_metrics.sql  
│       └── mart\_support\_performance.sql  
├── tests/  
│   ├── assert\_mrr\_is\_non\_negative.sql  
│   ├── assert\_active\_users\_have\_plan.sql  
│   └── assert\_open\_tickets\_have\_no\_resolution\_time.sql  
└── data\_contracts/  
    ├── contract\_mart\_user\_health.yml  
    ├── contract\_mart\_revenue\_metrics.yml  
    └── contract\_mart\_support\_performance.yml

---

## **Step 2: Staging Models (5 Models)**

## **stg\_users.sql**

SQL

\-- Standardizes user profiles: trims names, fixes casing, filters legacy plans  
SELECT   
    user\_id,  
    TRIM(name) AS user\_name,  
    LOWER(email) AS email,  
    UPPER(country) AS country\_code,  
    plan AS subscription\_plan,  
    CAST(signup\_date AS DATE) AS signup\_date  
FROM {{ source('raw', 'raw\_users') }}  
WHERE plan \!= 'trial'

## **stg\_subscriptions.sql**

SQL

\-- Cleans subscriptions: removes $0 MRR, derives activity status  
SELECT   
    subscription\_id,  
    user\_id,  
    plan AS subscription\_tier,  
    CAST(start\_date AS DATE) AS start\_date,  
    CAST(end\_date AS DATE) AS end\_date,  
    mrr,  
    CASE WHEN end\_date IS NULL THEN TRUE ELSE FALSE END AS is\_active  
FROM {{ source('raw', 'raw\_subscriptions') }}  
WHERE mrr \> 0

## **stg\_events.sql**

SQL

\-- High volume cleaning: removes QA tests, casts timestamps  
SELECT   
    event\_id,  
    user\_id,  
    event\_type,  
    CAST(event\_date AS TIMESTAMP) AS event\_at,  
    \-- properties\_json excluded to optimize performance at high volume  
    CAST(event\_date AS DATE) AS event\_date  
FROM {{ source('raw', 'raw\_events') }}  
WHERE event\_type \!= 'test'

## **stg\_invoices.sql**

SQL

\-- Revenue safety: filters out voided invoices  
SELECT   
    invoice\_id,  
    user\_id,  
    amount AS invoice\_amount,  
    CAST(invoice\_date AS DATE) AS invoice\_date,  
    status AS invoice\_status  
FROM {{ source('raw', 'raw\_invoices') }}  
WHERE status \!= 'void'

## **stg\_support\_tickets.sql**

SQL

\-- Support efficiency: filters duplicates and computes resolution speed  
SELECT   
    ticket\_id,  
    user\_id,  
    priority,  
    status AS ticket\_status,  
    created\_at,  
    resolved\_at,  
    CASE   
        WHEN resolved\_at IS NOT NULL   
        THEN EXTRACT(EPOCH FROM (resolved\_at \- created\_at)) / 3600   
        ELSE NULL   
    END AS resolution\_hours  
FROM {{ source('raw', 'raw\_support\_tickets') }}  
WHERE status \!= 'duplicate'

---

## **Step 3: Intermediate Models**

## **int\_users\_enriched.sql**

SQL

\-- Enriches user records with subscription state and login counts  
WITH user\_activity AS (  
    SELECT user\_id, COUNT(\*) AS total\_events, MAX(event\_at) AS last\_active\_at  
    FROM {{ ref('stg\_events') }}  
    GROUP BY 1  
)  
SELECT   
    u.\*,  
    s.subscription\_tier,  
    s.mrr,  
    s.is\_active AS has\_active\_subscription,  
    COALESCE(a.total\_events, 0) AS total\_events,  
    a.last\_active\_at,  
    CURRENT\_DATE \- u.signup\_date AS tenure\_days  
FROM {{ ref('stg\_users') }} u  
LEFT JOIN {{ ref('stg\_subscriptions') }} s ON u.user\_id \= s.user\_id AND s.is\_active \= TRUE  
LEFT JOIN user\_activity a ON u.user\_id \= a.user\_id

## **int\_support\_with\_users.sql**

SQL

\-- Links tickets to user metadata for plan-based support analysis  
SELECT   
    t.\*,  
    u.subscription\_plan,  
    u.country\_code,  
    CASE   
        WHEN t.priority \= 'critical' THEN 1  
        WHEN t.priority \= 'high' THEN 2  
        WHEN t.priority \= 'medium' THEN 3  
        ELSE 4   
    END AS priority\_rank  
FROM {{ ref('stg\_support\_tickets') }} t  
LEFT JOIN {{ ref('stg\_users') }} u ON t.user\_id \= u.user\_id

---

## **Step 4: Mart Models**

## **mart\_user\_health.sql**

SQL

\-- Consumer: Customer Success. Tracks churn risk based on activity and support volume.  
SELECT   
    user\_id,  
    user\_name,  
    subscription\_plan,  
    total\_events,  
    CASE   
        WHEN (CURRENT\_TIMESTAMP \- last\_active\_at) \> INTERVAL '30 days' THEN 'High Risk'  
        WHEN total\_events \< 5 THEN 'Low Engagement'  
        ELSE 'Healthy'  
    END AS churn\_risk\_status  
FROM {{ ref('int\_users\_enriched') }}

## **mart\_revenue\_metrics.sql**

SQL

\-- Consumer: Finance. Aggregates current MRR by plan.  
SELECT   
    subscription\_plan,  
    SUM(mrr) AS total\_mrr,  
    COUNT(DISTINCT user\_id) AS active\_customers  
FROM {{ ref('int\_users\_enriched') }}  
WHERE has\_active\_subscription \= TRUE  
GROUP BY 1

## **mart\_support\_performance.sql**

SQL

\-- Consumer: Support Ops. KPIs for resolution and load.  
SELECT   
    priority,  
    COUNT(ticket\_id) AS total\_tickets,  
    AVG(resolution\_hours) AS avg\_resolution\_hours,  
    COUNT(CASE WHEN ticket\_status \!= 'resolved' THEN 1 END) AS open\_tickets  
FROM {{ ref('int\_support\_with\_users') }}  
GROUP BY 1

---

## **Step 5: Custom Tests**

**assert\_mrr\_is\_non\_negative.sql**

SQL

SELECT \* FROM {{ ref('mart\_revenue\_metrics') }} WHERE total\_mrr \< 0

**assert\_active\_users\_have\_plan.sql**

SQL

SELECT \* FROM {{ ref('int\_users\_enriched') }}   
WHERE has\_active\_subscription \= TRUE AND subscription\_tier IS NULL

**assert\_open\_tickets\_have\_no\_resolution\_time.sql**

SQL

SELECT \* FROM {{ ref('stg\_support\_tickets') }}   
WHERE ticket\_status IN ('open', 'in\_progress') AND resolved\_at IS NOT NULL

---

## **Step 6: Data Contracts (Example: Mart Revenue)**

YAML

contract:  
  model: mart\_revenue\_metrics  
  description: "Official MRR breakdown by plan tier"  
  owner: "Finance Analytics"  
  consumers: \["CFO", "Revenue Operations"\]  
  columns:  
    \- name: subscription\_plan  
      type: VARCHAR  
      nullable: false  
    \- name: total\_mrr  
      type: NUMERIC  
      nullable: false  
      constraints: \["total\_mrr \>= 0"\]  
  freshness:  
    warn\_after: "12 hours"  
    error\_after: "24 hours"  
  sla:  
    availability: "99.9%"  
    refresh\_schedule: "0 6 \* \* \*"

---

## **Step 7: Dependency Graph (DAG)**

Plaintext

\[raw\_users\] \----------\> \[stg\_users\] \--------------┐  
\[raw\_subscriptions\] \--\> \[stg\_subscriptions\] \------\> \[int\_users\_enriched\] \----\> \[mart\_user\_health\]  
\[raw\_events\] \---------\> \[stg\_events\] \-------------┘                    └----\> \[mart\_revenue\_metrics\]  
                                                    
\[raw\_support\_tickets\] \-\> \[stg\_support\_tickets\] \---┐  
                                               ├──\> \[int\_support\_with\_users\] \-\> \[mart\_support\_performance\]  
\[stg\_users\] \--------------------------------------┘

**version: 2**

**sources:**

  \- name: raw

    description: "Raw landing zone for production app data and third-party integrations."

    database: cloudmetrics\_prod  \# Replace with your actual database name

    schema: public               \# Replace with your actual schema name

    

    \# Global freshness check: Alert if no data arrives for 24 hours

    freshness:

      warn\_after: {count: 24, period: hour}

      error\_after: {count: 48, period: hour}

    loaded\_at\_field: \_etl\_loaded\_at  \# Assumes your ETL tool adds a load timestamp

    tables:

      \- name: raw\_users

        description: "Primary user identity table."

        columns:

          \- name: user\_id

            tests: \[unique, not\_null\]

      \- name: raw\_subscriptions

        description: "Subscription history and MRR values."

        columns:

          \- name: subscription\_id

            tests: \[unique, not\_null\]

      \- name: raw\_events

        description: "Clickstream and feature usage data (High Volume)."

        freshness:

          warn\_after: {count: 1, period: hour} \# Stricter check for events

          error\_after: {count: 3, period: hour}

      \- name: raw\_invoices

        description: "Billing records for all subscription tiers."

      \- name: raw\_support\_tickets

**Description: "Customer support interactions from Zendesk/Intercom."**

name: 'cloudmetrics\_dbt'

version: '1.0.0'

config-version: 2

\# This setting tells dbt where to look for your files

model-paths: \["models"\]

test-paths: \["tests"\]

analysis-paths: \["analyses"\]

macro-paths: \["macros"\]

target-path: "target"

clean-targets:

  \- "target"

  \- "dbt\_packages"

\# Materialization Strategy

models:

  cloudmetrics\_dbt:

    \# Default: everything is a view to save storage cost

    \+materialized: view

    

    staging:

      \# Staging should stay as views for "live" cleaning

      \+materialized: view

      \+schema: staging

    intermediate:

      \# Intermediate can be ephemeral (logic-only) or views

      \+materialized: view

      \+schema: intermediate

    marts:

      \# Marts MUST be tables so dashboards (Tableau/PowerBI) run fast

      \+materialized: table

      \+schema: analytics

      \# Specific optimization for the high-volume support mart

      support:

        \+materialized: incremental

        \+unique\_key: ticket\_id

