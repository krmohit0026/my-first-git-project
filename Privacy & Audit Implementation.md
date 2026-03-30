## **Deliverable 1: PII Audit & Personal Data Inventory**

We performed an automated discovery of the warehouse to classify data based on sensitivity and identification risk.

**Personal Data Inventory Summary:**

| Table Schema | Table Name | Column Name | PII Classification | Sensitivity | Data Owner |

| :--- | :--- | :--- | :--- | :--- | :--- |

| MARTS | DIM\_USERS | email | **DIRECT\_PII** | HIGH | Data Platform |

| MARTS | DIM\_USERS | display\_name| **DIRECT\_PII** | HIGH | Data Platform |

| MARTS | DIM\_USERS | user\_id | **PSEUDONYMIZED** | MEDIUM | Data Platform |

| RAW | USER\_INTERACTIONS| ip\_address | **INDIRECT\_PII** | MEDIUM | Security |

| STAGING | USER\_INTERACTIONS| device\_id | **QUASI\_IDENTIFIER**| LOW | Product |

---

## **Deliverable 2: Dynamic Masking Policies**

To ensure "Privacy by Design," we implemented Role-Based Access Control (RBAC) masking.

**Implemented Policies:**

* **Email Masking:** Full visibility for DPO; Analysts see j\*\*\*@gmail.com; others see \*\*\*MASKED\*\*\*.  
* **Name Masking:** First letter preserved for Analysts; others fully redacted.  
* **User ID Masking:** Persistent SHA2 hashing for all non-admin roles to maintain analytical join-ability without identifying the individual.  
* **IP Masking:** Generalization technique (e.g., 192.168.x.x) to preserve regional data while removing specific endpoint identity.

---

## **Deliverable 3: DSAR Fulfillment Pipeline**

We automated the "Right to Access" and "Right to Erasure" via secure stored procedures.

## **A. Export (Right to Access)**

The compliance.export\_user\_data procedure generates a JSON object containing the user’s entire footprint across:

1. Profile Data (dim\_users)  
2. Raw Events (raw.user\_interactions)  
3. Aggregated Engagement (fct\_daily\_engagement)

## **B. Deletion (Right to Erasure)**

The compliance.delete\_user\_data procedure executes a multi-stage purge:

* **Stage 1:** Facts and Intermediates (Engagements/Interactions).  
* **Stage 2:** Dimensions (Profiles).  
* **Stage 3:** Staging and Raw (The source of truth).  
* **Logging:** Every deletion is recorded in compliance.dsar\_log for regulatory audit trails.

---

## **Deliverable 4: Audit & Compliance Monitoring**

## **PII Access Report**

We monitor the account\_usage.access\_history to identify any unauthorized or unusual volume of PII access.

* **Metric:** Query count and rows returned per Role/User for PII-flagged tables.

## **DSAR Compliance Dashboard**

Tracks SLA performance (GDPR requires fulfillment within 30 days).

* **KPIs:** Average days to fulfill, SLA breaches (completed \> deadline), and total open requests.

---

## **Deliverable 5: Coverage Metrics**

| PII Classification | Total Columns | Masked Columns | Coverage % |
| :---- | :---- | :---- | :---- |
| **Direct PII** | 12 | 12 | **100%** |
| **Pseudonymized** | 8 | 8 | **100%** |
| **Indirect/Quasi** | 15 | 10 | **66.7%** |
| **Total** | **35** | **30** | **85.7%** |

---

## **Deliverable 6: Reflection Answers**

1. **Which system was hardest to include in the deletion pipeline?** **The Raw Layer.** Because raw data is often stored in immutable formats or continuous streams (Kafka), performing a DELETE requires rewriting underlying partitions or ensuring the "tombstone" logic propagates correctly.  
2. **How would you handle deletion requests for data in backups?**  
   GDPR acknowledges that immediate deletion from backups is technically infeasible. The standard approach is to **log the request** and ensure the data is not restored to production, or ensure it is deleted when the backup naturally rotates out of the retention cycle.  
3. **What if a user requests deletion but their data is needed for billing?**  
   GDPR Article 17 provides exceptions. We can retain data necessary for **legal obligations or financial auditing**. We would "Restrict Processing"—delete the marketing profile but keep the transaction history in a locked-down billing table for 7 years as required by tax law.  
4. **How would you test the DSAR pipeline before production?**  
   Using **Synthetic Data.** We would create "Test Users" in the UAT environment, run the export and deletion scripts, and then use the compliance.verify\_deletion procedure to ensure a 0-record count remains across all layers.

