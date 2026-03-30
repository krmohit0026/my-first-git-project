## **Deliverable 1: Data Flow Trace (6-Layer Governance Overlay)**

| Layer | System | Quality Control | Privacy Control | Gaps Identified |
| :---- | :---- | :---- | :---- | :---- |
| **1: Sources** | Web/Mobile/API | Schema validation \[N\] | No PII masking \[N\] | Lack of upstream data contracts. |
| **2: Ingestion** | Kafka/NiFi | Schema Registry \[Y\] | No masking in transit \[N\] | PII is "clear-text" in Kafka topics. |
| **3: Staging** | dbt (stg\_ models) | Basic dbt tests \[Y\] | Static masking \[N\] | Sensitive data visible to all developers. |
| **4: Intermed.** | dbt (int\_ models) | Relationship tests \[Y\] | PII scrubbed \[Y\] | Complex logic often undocumented. |
| **5: Marts** | dbt (fct/dim) | Business rules \[Y\] | Dynamic masking \[N\] | No column-level security for HR/Fin. |
| **6: Consumers** | Tableau/ML | Dashboard checks \[N\] | Row-level security \[N\] | No "Certified" data watermarks. |

---

## **Deliverable 2 & 3: Scorecard & Maturity**

## **Pillar Scores**

* **Data Quality:** 65/100 (Strong on technical tests, weak on anomaly detection).  
* **Data Privacy:** 35/100 (High risk; missing dynamic masking and DSAR automation).  
* **Metadata:** 60/100 (Good dbt docs, but lacks a non-technical business glossary).  
* **Lineage:** 85/100 (Excellent due to dbt DAG integration).  
* **Compliance:** 55/100 (Basic RBAC in place, but lacks audit monitoring).

**Overall Total:** 300 / 500 (**60%**)

**Maturity Level:** **Level 2.5 (Developing)** — Transitioning from "Reactive" to "Defined."

---

## **Deliverable 4: Top 10 Governance Gaps**

| Rank | Gap | Pillar | Risk | Effort | Priority |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 1 | Clear-text PII in BI Layer | Privacy | HIGH | Med | P1 |
| 2 | No DSAR Deletion Workflow | Privacy | HIGH | High | P1 |
| 3 | Lack of Data Freshness SLAs | Quality | Med | Low | P1 |
| 4 | No Anomaly Detection | Quality | High | Med | P2 |
| 5 | Missing Business Glossary | Metadata | Low | Med | P2 |
| 6 | Lack of Column-Level Lineage | Lineage | Med | High | P2 |
| 7 | No Automated Audit Logs | Compliance | Med | Med | P2 |
| 8 | Manual Sensitivity Tagging | Metadata | Med | Low | P3 |
| 9 | No "Certified" Data Labels | Quality | Low | Low | P3 |
| 10 | Static Team Training | Compliance | Low | Med | P3 |

---

## **Deliverable 5: 90-Day Remediation Roadmap**

* **Month 1: Foundation (Security & Reliability)**  
  * Deploy Dynamic Data Masking for PII in Snowflake.  
  * Implement dbt-source-freshness monitoring.  
  * Success Criteria: 0 sensitive columns visible to unauthorized roles.  
* **Month 2: Standardization (Compliance)**  
  * Build an automated "Right to be Forgotten" (DSAR) script.  
  * Establish a central Business Glossary in the Data Catalog.  
  * Success Criteria: DSAR requests completed in \< 48 hours.  
* **Month 3: Automation (Scalability)**  
  * Integrate anomaly detection (e.g., Elementary or Monte Carlo).  
  * Automate sensitive data tagging via dbt-meta tags.  
  * Success Criteria: 90% of critical tables covered by anomaly alerts.

---

## **Deliverable 6: Executive Summary**

**GOVERNANCE AUDIT REPORT**

**Status:** Needs Improvement | **Maturity:** Level 2.5

**Current State:** The organization has excellent technical lineage thanks to dbt, but significant exposure exists regarding PII. Data quality is checked for nulls/uniques but lacks business-context monitoring.

**Top 3 Risks:**

1. **Legal:** Potential GDPR/CCPA fines due to lack of PII masking.  
2. **Trust:** Stakeholders lack a "Single Source of Truth" (Business Glossary).  
3. **Operational:** Data downtime goes undetected due to lack of anomaly alerts.

**Expected Outcome:** By following the 90-day plan, maturity will increase to **Level 4**, reducing compliance risk by 70% and improving data trust across the business.

---

## **Reflection Answers**

1. **Surprising Pillar:** **Lineage.** It is usually the hardest to achieve, but because this stack uses dbt, it is the strongest pillar by default.  
2. **30-Day Impact:** Implementing **Dynamic Data Masking**. It is a low-effort, high-reward security win that protects the company immediately.  
3. **Maintenance:** Move to **"Governance as Code."** Make metadata and tests a mandatory part of the CI/CD pipeline. If a PR doesn't have documentation, it cannot be merged.  
4. **SOC 2 Addition:** I would add **Access Reviews** (quarterly logs of who accessed what PII) and **Change Management** evidence (formal approval logs for every production code change).