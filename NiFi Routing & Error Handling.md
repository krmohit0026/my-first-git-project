---

## **Deliverable 1: Complete Flow Diagram**

* **The Split Stage:** GetFile → SplitText (to handle batches) → EvaluateJsonPath.  
* **The Validation Gate:** RouteOnAttribute checking for missing fields.  
* **The Multi-Path Router:** One RouteOnAttribute with three output arrows (interactions, transactions, eu\_events).  
* **The Dead Letter Logic:** UpdateAttribute → ReplaceText → PutFile (dead-letter).  
* **The Retry Loop:** A connection from the "failed" path that circles back to the transactions processor.

---

## **Deliverable 2: Dead Letter File Sample**

JSON

{  
  "error": {  
    "type": "missing\_field",  
    "timestamp": "2025-12-01 10:05:00",  
    "processor": "Validation",  
    "original\_filename": "batch-003.json"  
  },  
  "original\_event": {  
    "event\_id": "e006",  
    "action": "play",  
    "country": "JP",  
    "timestamp": "2025-12-01T10:00:00Z"  
  }  
}

---

## **Deliverable 3: Provenance Trace of a Retry**

1\. Go to **Data Provenance** for the UpdateAttribute processor in the retry loop.

2\. Select the **Lineage** view (the graph icon).

3\. **The Evidence:** You should see a "looping" pattern where the FlowFile has multiple **MODIFY\_ATTRIBUTES** events followed by a **ROUTE** back to the same processor.

4\. The retry\_count attribute should be visible in the details, incrementing (1, 2, 3, 4).

---

## **Deliverable 4: Answers to Reflection Questions**

**Q1: How would you adjust the retry limit for production?**

**Answer:** In production, I would move the retry limit (e.g., 4) into a **Global Controller Service** or a **Parameter Context**. This allows the limit to be adjusted across the entire NiFi cluster without stopping the individual processors. I would also implement an **Exponential Backoff** (increasing the delay each time) rather than a fixed 10-second penalty to give downstream systems more time to recover.

**Q2: What would you monitor to detect a spike in dead letter events?**

**Answer:** I would monitor the **Queue Size** and **Object Count** of the connection leading into the Dead Letter PutFile. Using NiFi's **S2S (Site-to-Site) Reporting Tasks**, I could send an alert to Grafana if the dead-letter count exceeds a specific threshold (e.g., more than 50 failures in 5 minutes), indicating a potential schema change or system outage.

**Q3: How would you reprocess dead letter events after fixing the root cause?**

**Answer:** I would create a separate "Reprocessing" flow. This flow would use GetFile to read from the /dead-letter/ directory, use EvaluateJsonPath to extract the $.original\_event, and then feed that cleaned data back into the main Ingest port of the primary flow. This "loops" the corrected data back through the validation logic.

