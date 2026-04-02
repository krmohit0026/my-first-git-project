

### **1\. The Multi-Event Producer (producer.py)**

I have completed the produce\_transaction logic. Note the use of order\_id as the message key to ensure all updates for a single transaction land in the same partition.

Python

* \# producer.py \- Completed logic  
* def produce\_transaction(self):  
*     """Generate and publish a transaction event."""  
*     order\_id \= str(uuid.uuid4())  
*     methods \= \['credit\_card', 'paypal', 'apple\_pay', 'google\_pay'\]  
*       
*     event \= {  
*         'order\_id': order\_id,  
*         'user\_id': f'user-{random.randint(1, 100):04d}',  
*         'amount': round(random.uniform(4.99, 19.99), 2),  
*         'currency': 'USD',  
*         'payment\_method': random.choice(methods),  
*         'status': 'success' if random.random() \> 0.1 else 'failed',  
*         'timestamp': datetime.utcnow().isoformat() \+ 'Z',  
*     }  
*   
*     self.producer.produce(  
*         topic=TOPICS\['transactions'\],  
*         key=order\_id,  
*         value=json.dumps(event),  
*         callback=self.\_callback,  
*     )

---

### **2\. The Engagement Consumer (consumers/engagement.py)**

This consumer tracks user behavior and "churn risk." I've used a defaultdict to calculate scores on the fly within the 10-second window.

Python

* \# consumers/engagement.py  
* from confluent\_kafka import Consumer  
* import json, time  
* from collections import defaultdict  
* from config import consumer\_config, TOPICS  
*   
* class EngagementConsumer:  
*     def \_\_init\_\_(self):  
*         self.consumer \= Consumer(consumer\_config('streampulse-engagement-v1'))  
*         self.consumer.subscribe(\[TOPICS\['user\_interactions'\]\])  
*         self.state \= defaultdict(lambda: {'score': 0, 'actions': \[\]})  
*         self.window\_start \= time.time()  
*   
*     def process(self, event):  
*         uid \= event.get('user\_id')  
*         action \= event.get('action')  
*           
*         \# Scoring Logic  
*         weights \= {'play': 1, 'complete': 2, 'like': 3, 'share': 5}  
*         self.state\[uid\]\['score'\] \+= weights.get(action, 0)  
*         self.state\[uid\]\['actions'\].append(action)  
*   
*     def emit\_report(self):  
*         active\_users \= len(self.state)  
*         if active\_users \== 0: return  
*           
*         \# Churn risk: Users who only skip  
*         churn\_risk \= \[u for u, s in self.state.items() if all(a \== 'skip' for a in s\['actions'\])\]  
*         avg\_score \= sum(s\['score'\] for s in self.state.values()) / active\_users  
*   
*         print(f"\\n--- ENGAGEMENT REPORT \---")  
*         print(f"Active Users: {active\_users} | Avg Score: {avg\_score:.2f}")  
*         print(f"Churn Risk Count: {len(churn\_risk)}")  
*         self.state.clear()  
*         self.window\_start \= time.time()  
*   
*     def run(self):  
*         print("Engagement Consumer running...")  
*         try:  
*             while True:  
*                 msg \= self.consumer.poll(1.0)  
*                 if msg and not msg.error():  
*                     self.process(json.loads(msg.value()))  
*                 if time.time() \- self.window\_start \>= 10:  
*                     self.emit\_report()  
*         except KeyboardInterrupt:  
*             self.consumer.close()

---

### **3\. The Revenue Consumer (consumers/revenue.py)**

Crucial for the business, this consumer aggregates financial data.

Python

* \# consumers/revenue.py  
* class RevenueConsumer:  
*     def \_\_init\_\_(self):  
*         self.consumer \= Consumer(consumer\_config('streampulse-revenue-v1'))  
*         self.consumer.subscribe(\[TOPICS\['transactions'\]\])  
*         self.revenue \= 0.0  
*         self.failed\_tx \= 0  
*         self.methods \= defaultdict(int)  
*         self.window\_start \= time.time()  
*   
*     def process(self, event):  
*         if event.get('status') \== 'success':  
*             self.revenue \+= event.get('amount', 0)  
*             self.methods\[event.get('payment\_method')\] \+= 1  
*         else:  
*             self.failed\_tx \+= 1  
*   
*     def emit\_report(self):  
*         print(f"\\n$$$ REVENUE REPORT $$$")  
*         print(f"Total Revenue: ${self.revenue:.2f} | Failed Trans: {self.failed\_tx}")  
*         print(f"Top Method: {max(self.methods, key=self.methods.get) if self.methods else 'N/A'}")  
*         self.revenue \= 0.0  
*         self.failed\_tx \= 0  
*         self.methods.clear()  
*         self.window\_start \= time.time()  
*   
*     def run(self):  
*         print("Revenue Consumer running...")  
*         try:  
*             while True:  
*                 msg \= self.consumer.poll(1.0)  
*                 if msg and not msg.error():  
*                     self.process(json.loads(msg.value()))  
*                 if time.time() \- self.window\_start \>= 10:  
*                     self.emit\_report()  
*         except KeyboardInterrupt:  
*             self.consumer.close()

---

### **4\. Engineering Review: Why this works**

* **Consumer Groups:** Each consumer has a unique group.id. This allows Kafka to broadcast the same message to **all three** consumers simultaneously.  
* **Manual Commits:** By setting enable.auto.commit: False, we ensure that if a consumer crashes midway through a window, it will re-read the unprocessed messages upon restart, maintaining data integrity.  
* **Threading:** The run\_pipeline.py script uses Python threads to simulate a distributed environment. In a real production scenario, these would be separate Docker containers or Kubernetes pods.  
* 

