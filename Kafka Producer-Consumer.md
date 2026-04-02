This is a classic Data Engineering challenge focusing on **Real-Time Stream Processing**. As your lead Data Engineer for this task, I have structured the solution to address the missing logic in the producer, implement the error-handling patterns in the consumer, and answer the architectural questions.

---

## **1\. Environment & Topic Setup**

We start by ensuring the infrastructure is provisioned. The create\_topics.py script ensures we have the correct partition counts for parallelism and retention policies for data lifecycle management.

Python

\# create\_topics.py (Completed)  
from confluent\_kafka.admin import AdminClient, NewTopic

admin \= AdminClient({'bootstrap.servers': 'localhost:9092'})

topics \= \[  
    NewTopic('streaming.user.interactions', num\_partitions=6, replication\_factor=1,   
             config={'retention.ms': str(30 \* 24 \* 60 \* 60 \* 1000)}),  
    NewTopic('streaming.user.page-views', num\_partitions=3, replication\_factor=1,   
             config={'retention.ms': str(7 \* 24 \* 60 \* 60 \* 1000)}),  
    NewTopic('payments.transaction.events', num\_partitions=3, replication\_factor=1,   
             config={'retention.ms': str(90 \* 24 \* 60 \* 60 \* 1000)}),  
    NewTopic('streaming.user.dead-letter', num\_partitions=1, replication\_factor=1,   
             config={'retention.ms': str(30 \* 24 \* 60 \* 60 \* 1000)})  
\]

\# Create topics and handle results  
futures \= admin.create\_topics(topics)  
for topic, future in futures.items():  
    try:  
        future.result()  
        print(f'Created topic: {topic}')  
    except Exception as e:  
        print(f'Topic {topic} status: {e}')

---

## **2\. Producer Implementation**

The producer now includes the missing generators for page views and transactions.

* **Page Views:** Track navigation flow.  
* **Transactions:** Include financial data for revenue tracking.

Python

\# Part of streampulse\_producer.py

def generate\_page\_view\_event():  
    user \= random.choice(USERS)  
    pages \= \['home', 'search', 'browse', 'profile', 'settings', 'player\_v2'\]  
    return {  
        'event\_id': str(uuid.uuid4()),  
        'user\_id': user,  
        'page\_url': f"streampulse.io/{random.choice(pages)}",  
        'referrer': random.choice(\['google.com', 'direct', 'facebook.com', 'email'\]),  
        'device': random.choice(DEVICES),  
        'timestamp': datetime.utcnow().isoformat() \+ 'Z'  
    }

def generate\_transaction\_event():  
    user \= random.choice(USERS)  
    plans \= {'basic': 9.99, 'standard': 15.99, 'premium': 19.99}  
    selected\_plan \= random.choice(list(plans.keys()))  
    return {  
        'order\_id': str(uuid.uuid4()),  
        'user\_id': user,  
        'plan\_type': selected\_plan,  
        'amount': plans\[selected\_plan\],  
        'currency': 'USD',  
        'status': 'success' if random.random() \> 0.05 else 'failed',  
        'timestamp': datetime.utcnow().isoformat() \+ 'Z'  
    }

---

## **3\. Analytics Consumer Implementation**

I have implemented the **Dead Letter Queue (DLQ)** pattern. This is vital in data engineering: if a record is "poisonous" (malformed), we don't want it to crash the pipeline or block the consumer; we route it to a side-topic for investigation.

Python

\# Part of streampulse\_consumer.py

def handle\_dead\_letter(self, msg, error):  
    """Publish malformed messages to the DLQ topic."""  
    dlq\_producer \= Producer({'bootstrap.servers': 'localhost:9092'})  
    payload \= {  
        'original\_data': msg.value().decode('utf-8') if msg.value() else None,  
        'error': error,  
        'topic': msg.topic(),  
        'partition': msg.partition(),  
        'offset': msg.offset(),  
        'timestamp': datetime.utcnow().isoformat()  
    }  
    dlq\_producer.produce('streaming.user.dead-letter', value=json.dumps(payload))  
    dlq\_producer.flush()  
    print(f'  \[ALARM\] Sent corrupt message to DLQ: offset={msg.offset()}')

\# Inside emit\_window method: Added Top Countries  
def emit\_window(self):  
    \# ... previous code ...  
    top\_countries \= sorted(w\['by\_country'\].items(),   
                           key=lambda x: x\[1\], reverse=True)\[:3\]  
    print(f'║  Countries: {", ".join(f"{c}:{cnt}" for c,cnt in top\_countries)}')  
    \# ... rest of method ...

---

## **4\. Post-Lab Analysis (Questions)**

### **How many events per second is the consumer processing?**

Based on the configuration, the producer sends **100 events/sec**. In a healthy state, the consumer should process roughly the same, provided the processing logic (JSON parsing \+ aggregation) stays under 10ms per message.

### **Is there any consumer lag?**

If the consumer processing speed \< 100 events/sec, lag will increase. You can monitor this using:

docker exec \-it \<kafka-container\> kafka-consumer-groups \--bootstrap-server localhost:9092 \--group streampulse-analytics-v1 \--describe

### **What happens if you slow down the consumer (time.sleep(0.01))?**

By adding a 10ms delay, the consumer can only process a maximum of **100 events/sec** ($1.0 / 0.01$). If the producer bursts above this, **Lag** will start to build. Eventually, the consumer might fall behind the retention period or trigger a rebalance if it takes too long between polls.

### **How would you scale the consumer?**

1. **Increase Partitions:** The interaction topic has 6 partitions.  
2. **Spin up more instances:** Run up to 6 instances of the consumer script using the same group.id. Kafka will automatically assign 1 partition to each consumer instance, allowing for parallel processing.

---

### **Final Check**

* \[x\] **Idempotence:** Enabled in producer to prevent duplicate writes.  
* \[x\] **Batching:** linger.ms and batch.size optimized for throughput.  
* \[x\] **Fault Tolerance:** Dead Letter Queue handles JSON errors.  
* \[x\] **State Management:** Manual commits ensure "at-least-once" delivery.

