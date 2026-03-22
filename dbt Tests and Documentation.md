

---

## **1\. Project Architecture & Documentation Strategy**

**The project follows a modular structure where every transformation layer serves a specific purpose, guarded by specific tests.**

## **Staging Layer: The First Line of Defense**

**We use schema.yml in the staging folder to document raw source cleaning.**

* **Tests: not\_null and unique on all primary keys. accepted\_values to ensure source systems haven't introduced new, unhandled statuses or categories.**

## **Intermediate Layer: Referential Integrity**

**The intermediate layer focuses on the "Enriched" order record.**

* **Tests: The relationships test is critical here. It ensures that after joining, every customer\_id and product\_id actually exists in the upstream staging models.**

## **Mart Layer: Business Reliability & Contracts**

**Marts are the "Authoritative Sources." We apply Data Contracts here to ensure schema stability and Custom Tests to validate business logic (e.g., revenue cannot be negative).**

---

## **2\. Testing & Documentation Implementation**

## **A. Staging & Intermediate (models/staging/schema.yml)**

**Each column is documented with a business description and structural tests.**

**YAML**

**version: 2**

**models:**

  **\- name: stg\_orders**

    **description: "Cleaned orders; excludes cancelled records."**

    **columns:**

      **\- name: order\_id**

        **description: "Primary Key"**

        **tests: \[unique, not\_null\]**

      **\- name: order\_status**

        **tests:**

          **\- accepted\_values:**

              **values: \['completed', 'pending'\]**

## **B. Custom Business Rule Tests (tests/\*.sql)**

**Custom tests are SQL queries that return failing rows. If the query returns 0 rows, the test passes.**

**Test: assert\_revenue\_by\_customer\_is\_positive.sql**

**SQL**

**\-- FAILS if revenue is 0 or negative**

**SELECT**

    **customer\_id,**

    **total\_revenue**

**FROM {{ ref('mart\_revenue\_by\_customer') }}**

**WHERE total\_revenue \<= 0**

---

## **3\. Mart Data Contracts**

**Data contracts define the "Agreement" with the business. We specify the exact data types and SLAs.**

| Feature | mart\_revenue\_by\_customer | mart\_revenue\_by\_product |
| :---- | :---- | :---- |
| **Owner** | **Analytics Engineering** | **Analytics Engineering** |
| **SLA Freshness** | **24 Hours** | **24 Hours** |
| **Critical Column** | **total\_revenue (NUMERIC)** | **total\_units\_sold (INT)** |
| **Constraint** | **total\_orders \> 0** | **unit\_price \> 0** |

---

## **4\. Test Inventory Summary**

**The project includes a total of 45 tests to ensure total visibility into data health.**

| Layer | Generic Tests | Custom Tests | Focus |
| :---- | :---- | :---- | :---- |
| **Staging** | **28** | **0** | **Format & Nulls** |
| **Intermediate** | **6** | **0** | **Referential Integrity** |
| **Marts** | **6** | **5** | **Business Logic & Accuracy** |

---

## **5\. Final Repository Folder Structure**

**Following dbt best practices, your repository should be organized as follows to support clear navigation and automated CI/CD testing:**

**Plaintext**

**cartwave\_dbt/**

**├── dbt\_project.yml**

**├── README.md**

**├── models/**

**│   ├── staging/**

**│   │   ├── schema.yml         \# Staging docs & generic tests**

**│   │   └── stg\_\*.sql**

**│   ├── intermediate/**

**│   │   ├── schema.yml         \# Join validation & relationship tests**

**│   │   └── int\_enriched.sql**

**│   └── marts/**

**│       ├── schema.yml         \# Mart docs & generic tests**

**│       └── mart\_\*.sql**

**├── tests/                     \# Custom SQL business tests**

**│   ├── assert\_revenue\_positive.sql**

**│   └── assert\_order\_logic.sql**

**└── data\_contracts/            \# Formal business agreements**

    **└── contract\_revenue.yml**

---

## **Success Criteria Checklist**

* **\[x\] Primary Keys: All PKs have unique and not\_null tests.**  
* **\[x\] Referential Integrity: relationships tests confirm foreign keys exist.**  
* **\[x\] Custom Logic: SQL tests return rows ONLY on failure (e.g., negative revenue).**  
* **\[x\] Documentation: Every model and key column contains a description.**  
* **\[x\] Contracts: Data contracts define types, constraints, and SLAs for Marts.**

