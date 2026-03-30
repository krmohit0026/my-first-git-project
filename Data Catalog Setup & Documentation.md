## **1\. Staging Layer Documentation (models/staging/schema.yml)**

The staging layer serves as the entry point for raw data, focusing on cleaning and type-casting.

YAML

version: 2  
models:  
  \- name: stg\_user\_interactions  
    description: "Cleaned and deduplicated user interaction events. Source: raw.user\_interactions."  
    meta: {owner: data-platform, tier: tier-1, contains\_pii: true}  
    columns:  
      \- name: event\_id  
        description: "Primary Key. UUID format."  
        tests: \[unique, not\_null\]  
      \- name: action  
        description: "Interaction type (play, skip, like, etc)."  
        tests: \[accepted\_values: {values: \[play, skip, like, share, purchase, refund\]}\]

  \- name: stg\_partner\_events  
    description: "Standardized events from external partners (Spotify, etc.). Maps partner codes to internal event types."  
    meta: {owner: partner-eng, tier: tier-2, contains\_pii: false}  
    columns:  
      \- name: partner\_event\_id  
        description: "Unique ID from external partner system."  
        tests: \[unique, not\_null\]  
      \- name: revenue\_usd  
        description: "Partner revenue share converted to USD."

  \- name: stg\_billing\_events  
    description: "Financial records for subscriptions and renewals. Source: raw.billing\_events."  
    meta: {owner: finance-it, tier: tier-1, contains\_pii: true}  
    columns:  
      \- name: billing\_event\_id  
        description: "Unique transaction ID for billing."  
        tests: \[unique, not\_null\]

---

## **2\. Mart Layer Documentation (models/marts/schema.yml)**

The Mart layer contains optimized tables for business intelligence and reporting.

YAML

version: 2  
models:  
  \- name: dim\_users  
    description: "SCD Type 2 table for user profiles and subscription status."  
    meta: {owner: marketing, tier: tier-1, contains\_pii: true}  
    columns:  
      \- name: user\_id  
        description: "Unique user identifier."  
        meta: {pii\_level: pseudonymized}  
      \- name: is\_premium  
        description: "Flag for paid subscribers."

  \- name: fct\_daily\_engagement  
    description: "Daily aggregation of user activity and engagement scoring."  
    columns:  
      \- name: engagement\_score  
        description: "Weighted metric: (play \+ 2\*like \+ 3\*share \- skip) / total \* 100"

  \- name: fct\_revenue  
    description: "Consolidated revenue facts from User, Partner, and Billing streams."  
    columns:  
      \- name: total\_revenue  
        description: "Aggregated USD revenue across all streams."

---

## **3\. Business Glossary**

| Term | Definition | Calculation | Source |
| :---- | :---- | :---- | :---- |
| **Active User** | User with ≥1 interaction in 24h. | COUNT(DISTINCT user\_id) | fct\_daily\_engagement |
| **Churned User** | No 'play' events in last 30 days. | MAX(date) \< CURRENT \- 30 | fct\_daily\_engagement |
| **Engagement Score** | Index of user interaction value. | (play+2\*like+3\*share-skip) | fct\_daily\_engagement |
| **DAU** | Daily Active Users. | COUNT(DISTINCT user\_id) | fct\_daily\_engagement |
| **Premium User** | User on a paid subscription tier. | WHERE is\_premium \= TRUE | dim\_users |
| **Conversion Rate** | % of free users becoming paid. | (Paid / Total) \* 100 | dim\_users |
| **Session** | Interactions with \<30m gap. | session\_id logic | int\_user\_sessions |
| **Content Play** | An interaction of type 'play'. | COUNT(\*) WHERE action='play' | fct\_user\_interactions |
| **WAU** | Weekly Active Users (7-day roll). | COUNT(DISTINCT user\_id) | fct\_daily\_engagement |
| **Revenue** | Total USD from purchases. | SUM(amount) | fct\_revenue |

---

## **4\. PII Classification & Audit**

| Model | Column | PII Level | GDPR Relevant | Access Restricted |
| :---- | :---- | :---- | :---- | :---- |
| stg\_user\_interactions | user\_id | Pseudonymized | Yes | Data Team |
| dim\_users | email | PII | Yes | Legal/HR Only |
| dim\_users | country | Internal | No | All Employees |
| fct\_revenue | total\_revenue | Sensitive | No | Finance/Exec |

---

## **5\. Documentation Coverage Report**

| Layer | Models | Columns | Description Coverage | Test Coverage |
| :---- | :---- | :---- | :---- | :---- |
| **Staging** | 3 / 3 | 24 / 24 | 100% | 100% |
| **Intermediate** | 3 / 3 | 28 / 30 | 93% | 70% |
| **Marts** | 7 / 7 | 48 / 50 | 96% | 90% |
| **Reports** | 3 / 3 | 15 / 15 | 100% | 50% |
| **TOTAL** | **16 / 16** | **115 / 119** | **96.6%** | **82.3%** |

---

## **6\. Reflection Answers**

* **Hardest table to describe?** int\_combined\_revenue, because it requires explaining how we resolve overlaps between partner-reported revenue and internal billing logs.  
* **Enforcing documentation?** Implement **dbt-checkpoint** in the CI pipeline to block any Pull Request where description fields are null.  
* **Undocumented risk?** **Institutional Knowledge Loss.** If a key engineer leaves, the "why" behind complex revenue logic vanishes, leading to future bugs.  
* **Glossary review?** Every **6 months** or after major product launches that introduce new user behaviors or revenue streams.

