---

## **Deliverable 1: Cluster Sizing Worksheet**

| Metric | Calculation | Result |
| :---- | :---- | :---- |
| **Total Write Throughput** | 50 MB/s (Ingress) × 3 (Replication Factor) | **150 MB/s** |
| **Brokers Needed (Raw)** | 150 MB/s ÷ 40 MB/s (Conservative per-broker cap) | **3.75 Brokers** |
| **With 50% Headroom** | 3.75 × 1.5 | **5.625 Brokers** |
| **Final Broker Count** | Rounded up to be divisible by 3 AZs | **6 Brokers** |
| **Daily Data (Replicated)** | 50 MB/s × 86,400s × 3 | **12,960 GB (12.9 TB)** |
| **7-Day Total Storage** | 12.9 TB × 7 | **90.3 TB** |
| **Per Broker Storage** | 90.3 TB ÷ 6 Brokers | **15.05 TB** |

**Instance Choice:** kafka.m5.2xlarge

**Justification:** Provides the best balance of RAM (32GB) for page caching and enough vCPUs (8) to handle the 15 independent consumer groups without hitting high context-switching overhead.

---

## **Deliverable 2: Terraform Configuration (main.tf)**

* **Security Group Ports:** \* Kafka TLS: **9094**  
  * Kafka IAM: **9098**  
* **MSK Cluster Config:**  
  * number\_of\_broker\_nodes: **6**  
  * instance\_type: **kafka.m5.2xlarge**  
  * volume\_size: **16000** (16TB in GB)  
  * client\_authentication: Set iam \= true (Best practice for AWS).

---

## **Deliverable 3: IAM Policies**

**Producer (Web App):**

* **Actions:** kafka-cluster:WriteData, kafka-cluster:DescribeTopic.  
* **Resource:** ...topic/streampulse-production/\*/streaming.raw.web-interactions.

**Consumer (Spark Streaming):**

* **Actions:** kafka-cluster:ReadData, kafka-cluster:DescribeTopic, kafka-cluster:AlterGroup, kafka-cluster:DescribeGroup.

---

## **Deliverable 4: Disaster Recovery Plan**

**Replication Strategy:** Use **MSK Replicator** (Serverless) to sync from us-east-1 to eu-west-1.

| Item | Configuration |
| :---- | :---- |
| **Replicated Topics** | streaming.raw.\*, streaming.enriched.\* |
| **Failover Trigger** | Manual (requires "Human-in-the-loop" to avoid split-brain). |
| **Failover Criteria** | AWS Region outage or \>15 mins of \>50% partition unavailability. |

---

## **Deliverable 5: Reflection Answers**

**Q1: What would change if throughput doubled in 6 months?**

**Answer:** We would perform a **Vertical Scale** (change instance type to m5.4xlarge) or a **Horizontal Scale** (increase broker count to 9 or 12). Because we used Terraform, we simply update the number\_of\_broker\_nodes and run terraform apply. Note: We would also need to increase the partition counts on existing topics to utilize the new brokers.

**Q2: How would you test the DR failover without impacting production?**

**Answer:** We would perform a **Dry Run** by pointing a "shadow" consumer group in the DR region to the DR cluster to verify data integrity and latency (RPO check). We would not switch the producers unless a real disaster occurs, as switching producers back (Failback) is complex and risks data duplication.

**Q3: What is the single most important monitoring metric and why?**

**Answer: Under-Replicated Partitions.** This is the "canary in the coal mine." If this is \> 0, it means the cluster is losing its durability guarantee. It indicates that a broker is struggling or dead, and if another fails, you will suffer permanent data loss.

