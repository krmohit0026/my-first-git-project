You're right to call that out—my previous response summarized the logic but didn't give you the full, copy-pasteable file with all 21 test cases.

To complete this assignment, you need the actual Python files and the dbt YAMLs structured exactly as the "Project Structure" requires. Here is the full, high-fidelity implementation of the assignment.

---

## **📂 Deliverable 1: Unit Tests (unit/test\_transformations.py)**

This file contains the **21 test cases** covering every edge case mentioned in the requirements.

Python

import pytest  
from datetime import datetime  
from transformations import (  
    classify\_user\_segment,  
    calculate\_engagement\_score,  
    parse\_timestamp,  
    is\_valid\_country\_code,  
    detect\_duplicate\_events  
)

class TestClassifyUserSegment:  
    \# 7 Tests: Covering all segments and boundaries  
    def test\_premium\_whale(self):  
        assert classify\_user\_segment(365, True, 150) \== "premium\_whale"  
    def test\_premium\_standard(self):  
        assert classify\_user\_segment(365, True, 50) \== "premium\_standard"  
    def test\_new\_user(self):  
        assert classify\_user\_segment(3, False, 0) \== "new\_user"  
    def test\_trial\_user(self):  
        assert classify\_user\_segment(15, False, 0) \== "trial\_user"  
    def test\_free\_user(self):  
        assert classify\_user\_segment(60, False, 0) \== "free\_user"  
    def test\_boundary\_day\_7(self):  
        assert classify\_user\_segment(7, False, 0) \== "new\_user"  
    def test\_boundary\_day\_30(self):  
        assert classify\_user\_segment(30, False, 0) \== "trial\_user"

class TestCalculateEngagementScore:  
    \# 5 Tests: Calculation and Null handling  
    def test\_perfect\_score(self):  
        assert calculate\_engagement\_score(10, 0, 0, 0) \== 100.0  
    def test\_zero\_score(self):  
        assert calculate\_engagement\_score(0, 0, 0, 10) \== 0.0  
    def test\_complex\_mix(self):  
        \# pos: 5 \+ (2\*2) \+ (1\*3) \= 12\. neg: 2\. total: 10\. (10/10)\*100  
        assert calculate\_engagement\_score(5, 2, 1, 2) \== 100.0  
    def test\_empty\_inputs(self):  
        assert calculate\_engagement\_score(0, 0, 0, 0) \== 0  
    def test\_null\_inputs(self):  
        assert calculate\_engagement\_score(None, None, None, None) \== 0

class TestParseTimestamp:  
    \# 4 Tests: Format and Error handling  
    def test\_standard\_iso(self):  
        ts \= parse\_timestamp("2025-12-01T10:00:00Z")  
        assert ts.year \== 2025 and ts.hour \== 10  
    def test\_none\_input\_error(self):  
        with pytest.raises(ValueError, match="Timestamp cannot be None"):  
            parse\_timestamp(None)  
    def test\_garbage\_string\_error(self):  
        with pytest.raises(ValueError, match="Invalid timestamp"):  
            parse\_timestamp("not-a-date")  
    def test\_empty\_string\_error(self):  
        with pytest.raises(ValueError):  
            parse\_timestamp("")

class TestIsValidCountryCode:  
    \# 5 Tests: Format and Nulls  
    def test\_valid\_code(self):  
        assert is\_valid\_country\_code("US") is True  
    def test\_lowercase\_fails(self):  
        assert is\_valid\_country\_code("us") is False  
    def test\_null\_passes(self):  
        assert is\_valid\_country\_code(None) is True  
    def test\_length\_fails(self):  
        assert is\_valid\_country\_code("USA") is False  
    def test\_non\_alpha\_fails(self):  
        assert is\_valid\_country\_code("12") is False

---

## **🏗️ Deliverable 2: dbt Schema Tests (models/schema.yml)**

This defines the data quality rules for your Snowflake tables.

YAML

version: 2  
models:  
  \- name: stg\_user\_interactions  
    columns:  
      \- name: event\_id  
        tests: \[unique, not\_null\]  
      \- name: action  
        tests:  
          \- accepted\_values:  
              values: \['play', 'skip', 'like', 'share', 'purchase', 'refund'\]  
      \- name: amount  
        tests:  
          \- dbt\_utils.expression\_is\_true:  
              expression: "\>= 0"  
              where: "action \= 'purchase'"

  \- name: fct\_daily\_engagement  
    tests:  
      \- dbt\_utils.expression\_is\_true:  
          expression: "engagement\_score BETWEEN 0 AND 100"  
    columns:  
      \- name: user\_id  
        tests:  
          \- relationships:  
              to: ref('dim\_users')  
              field: user\_id

---

## **📜 Deliverable 3: Contract Tests (contract/test\_contracts.py)**

This ensures your Kafka/API data doesn't change unexpectedly.

Python

from jsonschema import validate, ValidationError  
import pytest

\# Define the "Contract"  
USER\_SCHEMA \= {  
    "type": "object",  
    "required": \["event\_id", "user\_id", "action"\],  
    "properties": {  
        "event\_id": {"type": "string", "pattern": "^evt-\[0-9\]+$"},  
        "action": {"enum": \["play", "skip", "like", "purchase", "refund"\]},  
        "amount": {"type": \["number", "null"\], "minimum": 0}  
    }  
}

def test\_contract\_violation():  
    bad\_event \= {"event\_id": "123", "user\_id": "U1", "action": "attack"}  
    with pytest.raises(ValidationError):  
        validate(instance=bad\_event, schema=USER\_SCHEMA)

---

## **🚀 Deliverable 4: E2E Smoke Tests (e2e/test\_pipeline\_e2e.py)**

These check the final state of your Snowflake warehouse.

Python

def test\_warehouse\_health(snowflake\_conn):  
    \# 1\. Freshness Check (Data must be \< 6 hours old)  
    res \= snowflake\_conn.execute("SELECT MAX(timestamp) FROM fct\_trades").fetchone()  
    assert (datetime.now() \- res\[0\]).total\_seconds() / 3600 \< 6

    \# 2\. Row Count Check (Marts cannot be empty)  
    count \= snowflake\_conn.execute("SELECT COUNT(\*) FROM mart\_daily\_summary").fetchone()  
    assert count\[0\] \> 0

## **Step 5 — JSON Schema Contract**

This ensures that if a developer changes a field name in the source app, the pipeline **stops** before that "bad" data reaches your database.

Python  
\# contract/test\_contracts.py  
import pytest  
from jsonschema import validate, ValidationError

\# The "Contract" definition  
USER\_INTERACTION\_SCHEMA \= {  
    "type": "object",  
    "required": \["event\_id", "user\_id", "action", "timestamp"\],  
    "properties": {  
        "event\_id": {"type": "string", "pattern": "^evt-\[0-9\]+$"},  
        "user\_id": {"type": "string", "pattern": "^U-\[0-9\]+$"},  
        "action": {"type": "string", "enum": \["play", "skip", "like", "share", "purchase", "refund"\]},  
        "amount": {"type": \["number", "null"\], "minimum": 0},  
        "device": {"type": \["string", "null"\], "enum": \["web", "mobile", "tv", None\]},  
        "country": {"type": \["string", "null"\], "pattern": "^\[A-Z\]{2}$"},  
        "timestamp": {"type": "string", "format": "date-time"}  
    },  
    "additionalProperties": False  \# Blocks unexpected new fields (Schema Drift)  
}

class TestEventContract:  
    def test\_valid\_event(self):  
        """Verify a perfect event passes the contract."""  
        event \= {  
            "event\_id": "evt-001", "user\_id": "U-100",   
            "action": "play", "timestamp": "2026-03-30T10:00:00Z"  
        }  
        validate(instance=event, schema=USER\_INTERACTION\_SCHEMA)

    def test\_invalid\_action\_rejected(self):  
        """Verify 'attack' action triggers a failure."""  
        event \= {"event\_id": "evt-002", "user\_id": "U-101", "action": "attack", "timestamp": "2026-03-30T10:00:00Z"}  
        with pytest.raises(ValidationError):  
            validate(instance=event, schema=USER\_INTERACTION\_SCHEMA)

    def test\_negative\_amount\_rejected(self):  
        """Verify amount \< 0 triggers a failure."""  
        event \= {"event\_id": "evt-003", "user\_id": "U-102", "action": "purchase", "amount": \-5.0, "timestamp": "2026-03-30T10:00:00Z"}  
        with pytest.raises(ValidationError):  
            validate(instance=event, schema=USER\_INTERACTION\_SCHEMA)

##  Reflection Answers 

1. ## Hardest test? Contract tests, because you have to coordinate with the software engineers who build the source app to agree on the schema.

2. ## Most value? Unit tests. They are the fastest to run and catch the "dumb" logic errors before they ever cost money in Snowflake compute credits.

3. ## Flaky tests? Use a "Quarantine" tag. If a test fails inconsistently, move it to a separate suite that doesn't block the pipeline until it's fixed.

4. ## Health metrics? Test Pass Rate and Pipeline Lead Time (how much time testing adds to the deployment process).

## 

