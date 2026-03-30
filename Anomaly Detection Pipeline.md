---

## **Deliverable 1: Z-Score Analysis**

**Step 1: Baseline Statistics (Manual Calculation based on your data)**

To calculate the Z-score, we first need the mean ($\\mu$) and standard deviation ($\\sigma$) for the events.

* **Mean Events (Approx):** \~30,500 (Note: The dip on weekends and the "0" on Nov 28 pull this down).  
* **Standard Deviation:** High, due to the $0$ value on Nov 28 and the $96,000$ spike on Dec 01\.

**Step 3: Documenting Anomalies Found**

| Date | Events | Z-Score | Status | Explanation |

| :--- | :--- | :--- | :--- | :--- |

| **Nov 28** | 0 | \~ \-2.5 | **UNUSUAL** | Data is missing/dropped. Likely a pipeline failure. |

| **Dec 01** | 96,000 | \> 4.0 | **ANOMALY** | Massive volume spike (3x the average). |

| **Weekends** | \~22k | \~ \-1.1 | **NORMAL** | While lower than weekdays, they are consistent with each other. |

---

## **Deliverable 2: Moving Average & Seasonality**

**Step 4 & 5: Analysis**

The Moving Average (7-day) is better than a simple Z-score because it "smooths" out the data. However, as seen in your Step 5 code, **Weekday vs. Weekend separation** is the superior method.

* **Comparison:** Without separation, every Saturday/Sunday looks like a "dip" anomaly. With separation, we compare a Sunday to previous Sundays, showing that 22,000 events is actually "Normal" for a weekend.  
* **Dec 01 Result:** Even with a 7-day moving average, Dec 01 (96,000 events) shows a **\+190% deviation**, triggering a **CRITICAL\_ANOMALY** alert.

---

## **Deliverable 3: Distribution Drift**

**Step 6: Action Distribution Table**

| Action | Baseline % | Dec 01 % | Drift | Status |

| :--- | :--- | :--- | :--- | :--- |

| **Purchase** | 8.0% | 64.0% | **\+56.0%** | **CRITICAL** |

| **Play** | 45.0% | 18.0% | **\-27.0%** | **CRITICAL** |

**Insight:** This isn't just a volume spike; the *behavior* changed. Usually, people "Play" more than they "Purchase." On Dec 01, this flipped.

---

## **Deliverable 4: Reflection Answers (The "Why")**

## **1\. Which detection method caught the most anomalies?**

The **Z-score** method catches the most "statistical" anomalies, but the **Distribution Drift** (Step 6\) provides the most diagnostic value. It tells us *what* went wrong (a surge in purchases), not just that volume was high.

## **2\. Which method had the most false positives?**

The **Simple Z-score (Step 2\)**. It flags every weekend as "Unusual" because it doesn't understand that traffic naturally drops on Saturdays and Sundays.

## **3\. How would you handle the weekday/weekend pattern?**

I would implement **Seasonality-Adjusted Baselines** (as shown in Step 5). Instead of one global mean, maintain two: one for day\_type \= 'weekend' and one for day\_type \= 'weekday'.

## **4\. Is Dec 01 a data quality issue or a real business event?**

**It is likely a Data Quality issue (or a Bot attack).** \* **Evidence:** The Avg Amount jumped from \~$15 to \~$48, and Purchase events jumped from 8% to 64%.

* **How to tell:** I would check the user\_id logs. If the 96,000 events come from only a few IP addresses or new accounts, it’s a bot/test data leak. If it's across all users, it might be a massive sale (like Black Friday), but a 64% purchase rate is unnaturally high for a streaming service.

## **5\. How would you automate this to run daily?**

1. **Schedule:** Wrap the SQL in a tool like **dbt** or **Airflow** to run every morning at 06:00 UTC.  
2. **Alerting:** Add a HAVING clause or a WHERE status \= 'CRITICAL' filter.  
3. **Notification:** Integrate with Slack or PagerDuty to ping the Data Engineering team if a CRITICAL row is generated.

