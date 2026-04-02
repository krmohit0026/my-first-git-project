### **Part 1: Fault-Tolerant Infrastructure**

To support the requirements, your docker-compose.yml needs to explicitly define three separate brokers.

#### **Task A: 3-Broker Docker Compose**

YAML  
version: '3.8'  
services:  
  zookeeper:  
    image: confluentinc/cp-zookeeper:7.5.0  
    environment:  
      ZOOKEEPER\_CLIENT\_PORT: 2181

  kafka-1:  
    image: confluentinc/cp-kafka:7.5.0  
    ports: \["9092:9092"\]  
    environment:  
      KAFKA\_BROKER\_ID: 1  
      KAFKA\_ZOOKEEPER\_CONNECT: zookeeper:2181  
      KAFKA\_ADVERTISED\_LISTENERS: PLAINTEXT://localhost:9092  
      KAFKA\_MIN\_INSYNC\_REPLICAS: 2

  kafka-2:  
    image: confluentinc/cp-kafka:7.5.0  
    ports: \["9093:9093"\]  
    environment:  
      KAFKA\_BROKER\_ID: 2  
      KAFKA\_ZOOKEEPER\_CONNECT: zookeeper:2181  
      KAFKA\_ADVERTISED\_LISTENERS: PLAINTEXT://localhost:9093  
      KAFKA\_MIN\_INSYNC\_REPLICAS: 2

  kafka-3:  
    image: confluentinc/cp-kafka:7.5.0  
    ports: \["9094:9094"\]  
    environment:  
      KAFKA\_BROKER\_ID: 3  
      KAFKA\_ZOOKEEPER\_CONNECT: zookeeper:2181  
      KAFKA\_ADVERTISED\_LISTENERS: PLAINTEXT://localhost:9094  
      KAFKA\_MIN\_INSYNC\_REPLICAS: 2

---

### **Part 2: Instrumented Verification**

The code provided in the assignment is already quite robust. The key to passing this lab is the **Sequence Number (seq)**. By tracking incremental integers, the consumer can mathematically prove if a message was lost.

* **Producer:** Uses acks: all (ensures all ISRs have the data) and enable.idempotence: True (prevents duplicates during retries).  
* **Consumer:** Disables auto\_commit to ensure we only move the offset after we've successfully processed the seq.

---

### **Part 3: Failure Scenario Analysis (Expected Results)**

| Scenario | Producer Errors | Events Lost | Duplicates | Recovery Time |
| :---- | :---- | :---- | :---- | :---- |
| **1\. Follower Crash** | None (Retries handle it) | 0 | 0 | \< 1s |
| **2\. Leader Crash** | Brief LeaderNotAvailable | 0 | 0 (due to Idempotence) | 3s \- 5s |
| **3\. Two Brokers Down** | NotEnoughReplicas | 0 (Writes Blocked) | 0 | N/A (Manual intervention) |
| **4\. Consumer Kill** | None | 0 | Low (Re-reads from last commit) | 10s (Session Timeout) |
| **5\. Rolling Restart** | None | 0 | 0 | Instant |

---

### **Part 4: StreamPulse Failure Runbook (Draft)**

#### **Scenario: Leader Election Triggered**

* **Detection:** Producer logs show Expiring 1 record(s) ... due to transition. Monitoring shows a spike in request latency.  
* **Impact:** Transient (3-5 seconds) pause in throughput for affected partitions.  
* **Response:** No manual action required if acks=all is set. Kafka will automatically elect a new leader from the ISR.

#### **Scenario: min.insync.replicas Violation**

* **Detection:** Producer throws NotEnoughReplicasException.  
* **Impact:** **CRITICAL.** The pipeline is "Read-Only." No new data can be produced because the cluster cannot guarantee the safety level required.  
* **Response:** 1\. Identify the downed brokers using docker compose ps.  
  2\. Check broker logs for Disk Full or OOM (Out of Memory) errors.  
  3\. Restart the failed brokers immediately.

---

### **Part 5: Key Technical Takeaway**

The "Magic Formula" for Zero Data Loss in Kafka:

$$Replication Factor (3) \\ge min.insync.replicas (2) \+ 1$$  
This ensures that even if one broker dies, you still meet your minimum in-sync requirement ($3 \- 1 \= 2$), allowing the system to continue accepting writes safely. If you lose two brokers, the system stops writes to prevent data loss (since it can't meet the "2 replica" rule).

