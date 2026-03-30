## **Deliverable 1: dbt Masking Macros**

These macros allow us to handle PII differently depending on whether we are in a Production, Staging, or Development environment.

* **pii\_hash.sql**: In **Prod**, it passes data through. In **Staging**, it creates a deterministic SHA-256 hash with a salt for testing. In **Dev**, it returns a truncated "REDACTED" string.  
* **pii\_redact.sql**: Simply replaces values with \*\*\*REDACTED\*\*\* in any non-production target.  
* **pii\_generalize\_date.sql**: Truncates dates to the month level in non-prod environments to prevent re-identification through specific event timestamps.

---

## **Deliverable 2: Masked Staging Models**

We have updated the staging layer to use these macros, ensuring that PII is secured the moment it is transformed.

**stg\_user\_profiles.sql (Excerpt):**

SQL

SELECT  
    {{ pii\_hash('user\_id') }} as user\_id,  
    {{ pii\_redact('email') }} as email,  
    {{ pii\_redact('display\_name') }} as display\_name,  
    {{ pii\_generalize\_date('signup\_date') }} as signup\_date,  
    ...  
FROM {{ source('raw', 'user\_profiles') }}

**Verification:** We included dbt tests to ensure LENGTH(user\_id) \= 64 and ip\_address IS NULL in non-prod targets.

---

## **Deliverable 3: Dynamic Masking Policies**

For Production data, we implemented a **Universal Masking Policy** that adapts based on the user's role and the column type.

**Policy Logic:**

1. **SYSADMIN/DE/DPO**: Full access to raw values.  
2. **ANALYST**: Partial masking (e.g., j\*\*\*@gmail.com) and Hashed IDs.  
3. **MARKETING**: Domain-only email (e.g., \*\*\*@gmail.com) and fully hidden names.  
4. **PUBLIC/PARTNER**: Total redaction (\*\*\*MASKED\*\*\*).

---

## **Deliverable 4: Role Test Matrix**

Verification results across the StreamPulse role hierarchy:

| Role | email | display\_name | user\_id | Access Level |
| :---- | :---- | :---- | :---- | :---- |
| **DATA\_ENG** | john.doe@gmail.com | John Doe | U-12345 | **Full** |
| **DPO** | john.doe@gmail.com | John Doe | U-12345 | **Full** |
| **ANALYST** | j\*\*\*@gmail.com | J\*\*\* | SHA256(...) | **Partial** |
| **MARKETING** | \*\*\*@gmail.com | \*\*\* | SHA256(...) | **Limited** |
| **PARTNER** | \*\*\*MASKED\*\*\* | \*\*\*MASKED\*\*\* | \*\*\*MASKED\*\*\* | **None** |
| **PUBLIC** | \*\*\*MASKED\*\*\* | \*\*\*MASKED\*\*\* | \*\*\*MASKED\*\*\* | **None** |

---

## **Deliverable 5: Row-Level Security (RLS)**

We implemented a **Partner Row Access Policy** to ensure multi-tenancy security.

* **Logic**: The policy checks if the partner\_id in the row matches the partner\_id assigned to the user's current session.  
* **Exception**: Internal roles (ANALYST, DATA\_ENGINEER) bypass this policy to see aggregated data across all partners for global reporting.

---

## **Deliverable 6: Environment Strategy Document**

| Feature | Production | Staging | Development |
| :---- | :---- | :---- | :---- |
| **Data Source** | Real Live Data | Real Data (Anonymized) | Synthetic (Generated) |
| **PII Handling** | Dynamic Masking | Static Hashing | Full Redaction |
| **Access** | Strict RBAC | Data Team Only | All Developers |
| **Purpose** | Business Ops | QA / Testing | Feature Building |

---

## **Deliverable 7: Reflection Answers**

1. **Temporary PII access for an Analyst?** We would create a **Limited-Duration Role** (e.g., INVESTIGATOR) or use a "Just-In-Time" access request tool. The Analyst would be granted this role for 24 hours, after which the role expires and they revert to masked views.  
2. **New table without masking?** This is a **Data Leakage Risk**. We prevent this by running a daily "PII Audit" script (from the previous assignment) that flags any column names like 'email' or 'phone' that do not have a masking policy attached.  
3. **Detecting policy removal?** We monitor Snowflake **Audit Logs** (query\_history). Any ALTER TABLE ... UNSET MASKING POLICY command triggers an immediate CRITICAL alert to the Security/DPO Slack channel.  
4. **Performance impact?** At scale, dynamic masking has a **negligible impact** (usually \<5%) because the CASE statement is evaluated during query compilation. However, complex SHA2 hashing on billions of rows can increase compute time, so we often pre-hash IDs in the staging layer.

