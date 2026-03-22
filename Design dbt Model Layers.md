This is a comprehensive design for a dbt project. Since you are in "Design Mode," we will focus on the logic, the layering, and the SQL transformations.

Think of this as the **Blueprinting Phase**. You are defining the "Data Pipeline" that turns messy raw data into a clean, "Source of Truth" for CartWave's business teams.

---

## **Step 1: Staging Models (The "Cleaning" Room)**

Staging models are your 1:1 maps to raw data. Their only job is to clean, cast, and filter.

* **Key Rule:** Use {{ source('raw', 'table\_name') }}.  
* **Goal:** Create a "clean version" of the four raw tables.

| Model File | Key Transformation | Logic |
| :---- | :---- | :---- |
| stg\_orders.sql | Remove Cancelled | WHERE status \!= 'cancelled' |
| stg\_customers.sql | Clean Names/Emails | TRIM(name), LOWER(email) |
| stg\_products.sql | Fix Categories | LOWER(TRIM(category)) |
| stg\_payments.sql | Filter Success | WHERE status \= 'completed' |

---

## **Step 2: Intermediate Model (The "Enrichment" Room)**

This is where we join the clean staging models. This model provides a wide, flat view of every single order.

**int\_orders\_enriched.sql**

SQL

SELECT  
    o.\*, \-- Order details  
    c.customer\_name, c.country\_code, \-- Customer details  
    p.product\_name, p.product\_category, \-- Product details  
    pay.payment\_amount, \-- Payment details  
    (o.quantity \* p.unit\_price) AS line\_total \-- Business Logic  
FROM {{ ref('stg\_orders') }} o  
LEFT JOIN {{ ref('stg\_customers') }} c ON o.customer\_id \= c.customer\_id  
LEFT JOIN {{ ref('stg\_products') }} p ON o.product\_id \= p.product\_id  
LEFT JOIN {{ ref('stg\_payments') }} pay ON o.order\_id \= pay.order\_id

---

## **Step 3: Mart Models (The "Dashboard" Room)**

These are the final tables business users actually see. They are aggregated and fast.

1. **mart\_revenue\_by\_customer.sql**: Aggregates SUM(payment\_amount) by customer\_id.  
2. **mart\_revenue\_by\_product.sql**: Aggregates SUM(quantity) and SUM(payment\_amount) by product\_id.

---

## **Step 4: The Dependency Graph (DAG)**

dbt builds this graph automatically based on your {{ ref() }} tags. It ensures that stg\_orders is built **before** int\_orders\_enriched.

Plaintext

\[Sources\] \-\> \[Staging Models\] \-\> \[Intermediate\] \-\> \[Marts\]  
(Raw Data)    (Cleaning)          (Joining)        (Aggregating)

---

## **Step 5: Folder Structure Documentation**

To keep your Git repository organized, follow this standard dbt layout:

cartwave\_dbt\_project/  
├── dbt\_project.yml  
├── README.md  
├── models/  
│   ├── staging/  
│   │   ├── \_sources.yml         \<-- (The file above)  
│   │   ├── stg\_orders.sql  
│   │   ├── stg\_customers.sql  
│   │   ├── stg\_products.sql  
│   │   └── stg\_payments.sql  
│   ├── intermediate/  
│   │   └── int\_orders\_enriched.sql  
│   └── marts/  
│       ├── mart\_revenue\_by\_customer.sql  
│       └── mart\_revenue\_by\_product.sql

---

## **Success Checklist Verification:**

* \[x\] **Source usage:** Staging models use {{ source() }}.  
* \[x\] **Ref usage:** Intermediate/Marts use {{ ref() }}.  
* \[x\] **Data Quality:** Cancelled orders and failed payments are excluded early (in Staging).  
* \[x\] **Standardization:** All categories are lowercase and names are trimmed.

**version: 2**

**sources:**

  **\- name: raw**

    **description: "Raw transactional data from the CartWave e-commerce platform."**

    **database: raw\_data\_warehouse  \# Change this to your actual DB name**

    **schema: raw\_data**

    **tables:**

      **\- name: raw\_orders**

        **description: "One row per order attempt."**

        **columns:**

          **\- name: order\_id**

            **tests:**

              **\- unique**

              **\- not\_null**

          **\- name: status**

            **description: "Status can be 'completed', 'pending', or 'cancelled'."**

      **\- name: raw\_customers**

        **description: "Customer profile data including contact info."**

        **columns:**

          **\- name: customer\_id**

            **tests:**

              **\- unique**

              **\- not\_null**

          **\- name: email**

            **description: "Customer email (needs cleaning in staging)."**

      **\- name: raw\_products**

        **description: "Product catalog with unit pricing."**

        **columns:**

          **\- name: product\_id**

            **tests:**

              **\- unique**

          **\- name: unit\_price**

            **description: "Price in USD."**

      **\- name: raw\_payments**

        **description: "Payment transaction records."**

        **columns:**

          **\- name: payment\_id**

            **tests:**

              **\- unique**

          **\- name: status**

            **description: "Only 'completed' should be used for revenue."**

