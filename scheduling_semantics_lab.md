## **Step 1: Core Scheduling Concepts Review**

Before diving into the fixes, it is essential to internalize how Airflow perceives time. Airflow is designed for **data intervals**, meaning a task running today is typically processing data from yesterday.

---

## **Step 2: Part 1 — Fix 5 Broken DAG Configurations**

### **Broken Config 1: The DAG That Never Stops Changing**

**What is wrong:** `start_date=datetime.now()` is dynamic. Airflow re-evaluates the DAG file frequently; every time it does, the `start_date` moves forward, preventing the first interval from ever completing. **The fix:**

with DAG(  
    dag\_id="daily\_sales\_report",  
    start\_date=datetime(2024, 1, 1), \# Static date  
    schedule\_interval="@daily",  
    catchup=False,  
) as dag:

### **Broken Config 2: The DAG That Spawns 180 Runs**

**What is wrong:** `catchup=True` (the default) combined with a `start_date` far in the past. Airflow attempts to backfill every day since January, overwhelming the system. **The fix:**

with DAG(  
    dag\_id="customer\_sync",  
    start\_date=datetime(2024, 1, 1),  
    schedule\_interval="@daily",  
    catchup=False, \# Only process the most recent interval  
) as dag:

### **Broken Config 3: The Non-Deterministic Task**

**What is wrong:** Using `datetime.now()` inside the function makes the query depend on when the task runs rather than the period it's supposed to cover. This breaks re-runs and idempotency. **The fix:**

**def process\_daily\_data(\*\*context):**

    **target\_date \= context\["ds"\] \# execution\_date (YYYY-MM-DD)**

    **query \= f"SELECT \* FROM orders WHERE order\_date \= '{target\_date}'"**

### **Broken Config 4: The DAG That Never Triggers**

**What is wrong: `start_date` is in the year 2099\. Airflow will wait until 2099-01-02 to trigger the first run. The fix: Set the `start_date` to a date in the past relative to today.**

### **Broken Config 5: The Template-Unaware Midnight Task**

**What is wrong: The code manually subtracts a day from `today()`. If the task fails and retries the next day, "yesterday" will point to the wrong date. The fix: Use `context["ds"]`, which is immutable and tied to the specific DAG run interval.**

---

## **Step 3: Part 2 — Timeline Exercises**

### **Exercise 1: Daily Schedule**

**A DAG run triggers at the end of its data interval.**

| Run \# | Data Interval Start | Data Interval End | DAG Run Triggers At | execution\_date |
| :---- | :---- | :---- | :---- | :---- |
| **1** | **2024-01-01 00:00** | **2024-01-01 23:59** | **2024-01-02 00:00** | **2024-01-01** |
| **2** | **2024-01-02 00:00** | **2024-01-02 23:59** | **2024-01-03 00:00** | **2024-01-02** |

### **Exercise 3: Weekly Schedule (Mondays at 6 AM)**

**Given: `start_date` \= 2024-06-01 (Saturday).**

* **Observation: The first available Monday after the `start_date` is 2024-06-03.**  
* **Result: The first interval is June 3rd to June 10th. The first run triggers on June 10th at 06:00 AM.**

---

## **Step 4: Part 3 — Template Exercises**

### **Template Exercise 3: Partition Path (Year/Month/Day)**

**Instead of using `datetime.now()`, which provides the current time, we use the components of the execution date to ensure we write to the correct historical partition.**

**Corrected Code:**

**def write\_partition(\*\*context):**

    **execution\_date \= context\["execution\_date"\]**

    **partition\_path \= f"/data/year={execution\_date.year}/month={execution\_date.month:02d}/day={execution\_date.day:02d}/"**

    **print(f"Writing to partition: {partition\_path}")**

### **Template Exercise 4: Time-Range Query**

**Using `data_interval_start` and `data_interval_end` is the most reliable way to define query boundaries.**

**Corrected Code:**

**def extract\_range(\*\*context):**

    **start \= context\["data\_interval\_start"\]**

    **end \= context\["data\_interval\_end"\]**

    **query \= f"SELECT \* FROM logs WHERE created\_at \>= '{start}' AND created\_at \< '{end}'"**

**Step 5: Scheduling Cheat Sheet**

| Concept | Wrong Way | Right Way |
| :---- | :---- | :---- |
| **start\_date** | **datetime.now()** | **datetime(2024, 1, 1\)** |
| **Logic Date** | **datetime.today()** | **{{ ds }} or context\["ds"\]** |
| **Path Formatting** | **.strftime()** | **{{ ds\_nodash }}** |
| **Backfills** | **catchup=True (by accident)** | **catchup=False** |

