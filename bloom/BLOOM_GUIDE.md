# Bloom Guide — Search Phrases & Scene Actions

This guide defines the **search phrases** and **scene actions** to configure in Neo4j Bloom for the Data Asset Intelligence Graph demo.

Each entry includes:
- The phrase or action label
- What it does
- The Cypher it runs

---

## Search Phrases

Search phrases allow users to type natural language into the Bloom search bar and get a pre-built graph visualisation back instantly.

---

### 🔍 Show full lineage of [Dataset]

**Purpose:** Visualise the complete dependency chain from a dataset to its downstream strategies.

**Cypher:**
```cypher
MATCH path = (d:Dataset)
             -[:FEEDS]->(fp:FeaturePipeline)
             -[:GENERATES]->(f:Feature)
             -[:USED_IN]->(m:Model)
             -[:POWERS]->(s:Strategy)
WHERE d.name CONTAINS $Dataset
RETURN path
```

**Parameter:** `$Dataset` → user types dataset name

---

### 🔍 Show datasets expiring soon

**Purpose:** Surface all datasets whose contracts are within 90 days of renewal.

**Cypher:**
```cypher
MATCH (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)
WHERE date(prov.renewal_date) <= date() + duration('P90D')
  AND date(prov.renewal_date) >= date()
RETURN v, prov, d
```

---

### 🔍 Show impact of losing [Dataset]

**Purpose:** Show all models and strategies that would be affected if a dataset were removed.

**Cypher:**
```cypher
MATCH path = (d:Dataset)
             -[:FEEDS*1..3]->(f:Feature)
             -[:USED_IN]->(m:Model)
             -[:POWERS]->(s:Strategy)
WHERE d.name CONTAINS $Dataset
RETURN path
```

**Parameter:** `$Dataset` → user types dataset name

---

### 🔍 Show all datasets from [Vendor]

**Purpose:** Show the full data portfolio of a specific vendor and what it connects to.

**Cypher:**
```cypher
MATCH path = (v:DataVendor)-[:PROVIDES]->(d:Dataset)
             -[:FEEDS]->(fp:FeaturePipeline)
WHERE v.name CONTAINS $Vendor
RETURN path
```

**Parameter:** `$Vendor` → user types vendor name

---

### 🔍 Show strategy [Strategy] dependencies

**Purpose:** Show everything feeding into a given strategy — models, features, pipelines, datasets.

**Cypher:**
```cypher
MATCH path = (d:Dataset)
             -[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(:Feature)
             -[:USED_IN]->(:Model)
             -[:POWERS]->(s:Strategy)
WHERE s.name CONTAINS $Strategy
RETURN path
```

**Parameter:** `$Strategy` → user types strategy name

---

### 🔍 Show substitutable datasets

**Purpose:** Reveal the substitution map — which datasets could replace others.

**Cypher:**
```cypher
MATCH path = (d1:Dataset)-[r:SUBSTITUTABLE_FOR]->(d2:Dataset)
RETURN path
```

---

### 🔍 Show correlated features

**Purpose:** Surface redundant features with high R² correlation.

**Cypher:**
```cypher
MATCH path = (f1:Feature)-[r:CORRELATED_WITH]->(f2:Feature)
WHERE r.r_squared >= 0.45
RETURN path
```

---

### 🔍 Show live models

**Purpose:** Show all models currently in production and the strategies they power.

**Cypher:**
```cypher
MATCH path = (m:Model {status: 'Live'})-[:POWERS]->(s:Strategy)
RETURN path
```

---

### 🔍 Show high MNPI risk datasets

**Purpose:** Surface datasets flagged for high regulatory risk exposure.

**Cypher:**
```cypher
MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
WHERE d.mnpi_risk_score >= 0.5
MATCH path = (d)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(:Feature)-[:USED_IN]->(m:Model)
RETURN path
```

---

## Scene Actions

Scene actions appear as right-click context menus on nodes in Bloom. They let users drill into a selected node dynamically.

---

### ▶ Expand downstream from this Dataset

**Trigger node:** `Dataset`

**Purpose:** When a user right-clicks a Dataset node, expand everything it feeds into.

**Cypher:**
```cypher
MATCH path = (d:Dataset {id: $id})
             -[:FEEDS]->(fp:FeaturePipeline)
             -[:GENERATES]->(f:Feature)
             -[:USED_IN]->(m:Model)
RETURN path
```

---

### ▶ Show contract details for this Dataset

**Trigger node:** `Dataset`

**Purpose:** Show the vendor and contract relationship properties for the selected dataset.

**Cypher:**
```cypher
MATCH path = (v:DataVendor)-[prov:PROVIDES]->(d:Dataset {id: $id})
RETURN path
```

---

### ▶ Show substitutes for this Dataset

**Trigger node:** `Dataset`

**Purpose:** Show what datasets could replace the selected one.

**Cypher:**
```cypher
MATCH path = (d:Dataset {id: $id})-[r:SUBSTITUTABLE_FOR]->(alt:Dataset)
RETURN path
```

---

### ▶ Show all features used in this Model

**Trigger node:** `Model`

**Purpose:** Expand the feature inputs to the selected model, with Shapley values.

**Cypher:**
```cypher
MATCH path = (f:Feature)-[r:USED_IN]->(m:Model {id: $id})
RETURN path
```

---

### ▶ Trace full data supply chain for this Model

**Trigger node:** `Model`

**Purpose:** Show every upstream dataset feeding into the selected model.

**Cypher:**
```cypher
MATCH path = (d:Dataset)
             -[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(f:Feature)
             -[:USED_IN]->(m:Model {id: $id})
RETURN path
```

---

### ▶ Show PnL history for this Strategy

**Trigger node:** `Strategy`

**Purpose:** Expand all PnL records for the selected strategy.

**Cypher:**
```cypher
MATCH path = (s:Strategy {id: $id})-[:PRODUCES]->(p:PnL)
RETURN path
```

---

### ▶ Show all datasets powering this Strategy

**Trigger node:** `Strategy`

**Purpose:** Full reverse traversal from Strategy back to raw data inputs.

**Cypher:**
```cypher
MATCH path = (d:Dataset)
             -[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(:Feature)
             -[:USED_IN]->(:Model)
             -[:POWERS]->(s:Strategy {id: $id})
RETURN path
```

---

### ▶ Show correlated features for this Feature

**Trigger node:** `Feature`

**Purpose:** Show other features that are statistically correlated with the selected one.

**Cypher:**
```cypher
MATCH path = (f:Feature {id: $id})-[r:CORRELATED_WITH]-(other:Feature)
RETURN path
```

---

## Suggested Bloom Perspective Configuration

**Node colours (suggested):**
| Node | Colour |
|---|---|
| DataVendor | Purple |
| Dataset | Orange |
| FeaturePipeline | Blue |
| Feature | Teal |
| Model | Green |
| Strategy | Red |
| PnL | Yellow |

**Node size:** Map `Dataset` size to `annual_license_cost` — bigger bubble = more expensive dataset.

**Edge labels to show:**
- `PROVIDES` → show `renewal_date`
- `USED_IN` → show `shapley_value`
- `POWERS` → show `signal_weight`
- `SUBSTITUTABLE_FOR` → show `overlap_score`

**Caption properties:**
- Dataset: `name` + `annual_license_cost`
- Model: `name` + `live_sharpe`
- Strategy: `name` + `aum_usd_m`
