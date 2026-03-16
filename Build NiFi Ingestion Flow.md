---

## **Deliverable 1: Complete NiFi Flow**

* **Ingest Group:** Should contain GetFile connected to EvaluateJsonPath.  
* **Route Group:** Should contain RouteOnAttribute connected to two PutFile processors (Interactions/Transactions) and one LogAttribute (Unmatched).  
* **Error Handling Group:** Should contain UpdateAttribute connected to a PutFile (Errors).  
* **Connection Labels:** All connections should be labeled (e.g., success, failure, matched, interactions, transactions).

---

## **Deliverable 2: Provenance Trace for event-005-bad.json**

1\. Right-click the EvaluateJsonPath processor and select **"View data provenance"**.

2\. Find the event with the "Type" listed as **ROUTE** or **DROP** where the relationship was failure.

3\. Click the **"i" (Information) icon** on the far left.

4\. **Screenshot A:** The "Attributes" tab showing error.type: parse\_failure and error.source: EvaluateJsonPath.

5\. **Screenshot B:** The "Content" tab \-\> "View" to show the malformed text: {"event\_id": "evt-005", "user\_id": "U-7890" INVALID JSON.

---

## **Deliverable 3: Output Verification (File Lists)**

**1\. Interactions (3 files expected):**

Bash

ls /tmp/nifi-lab/output/interactions/  
\# Result:  
event-001.json  \# (action: play)  
event-003.json  \# (action: skip)  
event-004.json  \# (action: like)

**2\. Transactions (1 file expected):**

Bash

ls /tmp/nifi-lab/output/transactions/  
\# Result:  
event-002.json  \# (action: purchase)

**3\. Errors (1 file expected):**

Bash

ls /tmp/nifi-lab/output/errors/  
\# Result:  
event-005-bad.json \# (Invalid JSON)

---

## **Deliverable 4: Answers to Reflection Questions**

**Q1: What would happen if the input directory receives 10,000 files per minute?**

**Answer:** NiFi would trigger **Back Pressure**. When the queue between processors reaches the configured threshold (e.g., 10,000 objects), the upstream processor (GetFile) will automatically stop pulling new files. This prevents the system from running out of memory and ensures the pipeline stays stable under heavy load.

**Q2: How would you modify this flow to send to Kafka instead of PutFile?**

**Answer:** I would replace the PutFile processors with the **PublishKafka\_2\_6** processor. I would configure the Kafka Broker address (e.g., localhost:9092) and set the Topic Name to ${action} or a static name like fluxcart-events. This would transform the batch file process into a real-time streaming event bus.

**Q3: What monitoring would you add for production?**

**Answer:** I would implement **Bulletin Alerts** (using PutEmail or PutSlack) on the failure relationships to be notified immediately of data issues. Additionally, I would use the **Reporting Tasks** feature to send metrics (FlowFiles In/Out, JVM Memory) to an external monitoring tool like Grafana or Datadog.

**Once you have captured your screenshots of the canvas and the provenance window, you are ready to submit\! Do you need help with any of the NiFi Expression Language syntax before you wrap up?**

