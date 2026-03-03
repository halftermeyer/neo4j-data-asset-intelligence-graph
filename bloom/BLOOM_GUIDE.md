# Bloom Guide — Data Asset Intelligence Graph

This guide documents the **perspective**, **scene actions**, and **search phrase templates** configured in Neo4j Bloom for the Data Asset Intelligence Graph demo.

---

## Perspective

File: `bloom/data asset intel perspective.json`
Import it via **Bloom → Perspectives → Import**.

---

## Node Styling

| Label | Color | Caption | Key properties in tooltip |
|---|---|---|---|
| Dataset | #FFE081 (yellow) | `name` | `category`, `annual_license_cost`, `mnpi_risk_score`, `signal_half_life_days`, `active` |
| DataVendor | #C990C0 (purple) | `name` | `tier`, `hq_country`, `category` |
| Feature | #F79767 (orange) | `name` | `factor_type`, `coverage_universe`, `lookback_days`, `is_proprietary` |
| FeaturePipeline | #57C7E3 (cyan) | `name` | `team_owner`, `language`, `compute_cost_annual` |
| Model | #F16667 (red) | `name` | `model_type`, `live_sharpe`, `backtest_sharpe`, `status` |
| Strategy | #8DCC93 (green) | `name` | `approach`, `aum_usd_m`, `asset_class`, `target_sharpe` |
| PnL | #D9C8AE (beige) | `period` | `net_pnl_usd_m`, `sharpe`, `max_drawdown_pct` |

---

## Relationship Properties

| Relationship | Properties shown |
|---|---|
| PROVIDES | `renewal_date`, `annual_fee_usd`, `auto_renew`, `notice_period_days`, `contract_start`, `exclusivity` |
| USED_IN | `shapley_value`, `importance_rank`, `in_production` |
| POWERS | `signal_weight`, `since_year` |
| FEEDS | `primary_input` |
| GENERATES | `transformation` |
| SUBSTITUTABLE_FOR | `overlap_score`, `cost_delta_usd` |
| CORRELATED_WITH | `r_squared`, `detected_date` |
| PRODUCES | — |

> **Tip:** For PROVIDES and SUBSTITUTABLE_FOR, use Bloom's built-in **Expand** rather than scene actions — the relationship properties are rich enough on their own.

---

## Search Phrase Templates

Search phrases are typed in the Bloom search bar and return a graph visualisation. Parameters prompt the user for a value.

---

### 1. `Renewals before $date`

**Story:** "What contracts do I need to decide on before a given date?"

**Parameter:** `$date` — String (type a date, e.g. `2025-06-01`)

> **Autocompletion query** to add on `$date`:
> ```cypher
> MATCH ()-[prov:PROVIDES]->()
> WITH DISTINCT prov.renewal_date AS date
> ORDER BY date
> RETURN date
> ```

**Cypher:**
```cypher
MATCH path = (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)
WHERE date(prov.renewal_date) <= date($date)
  AND date(prov.renewal_date) >= date('2025-01-01')
RETURN path
```

---

### 2. `Datasets with MNPI risk above $score`

**Story:** Compliance review — surfaces high-risk datasets feeding live models.

**Parameter:** `$score` — Float, autocompletes from `Dataset.mnpi_risk_score`

**Cypher:**
```cypher
MATCH path = (:DataVendor)-[:PROVIDES]->(d:Dataset)
             -[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(:Feature)
             -[:USED_IN]->(m:Model)
WHERE d.mnpi_risk_score >= toFloat($score)
  AND m.status = 'Live'
RETURN path
```

---

### 3. `Live models with Sharpe below $threshold`

**Story:** Flags underperforming models — leads naturally into dataset attribution questions.

**Parameter:** `$threshold` — Float, autocompletes from `Model.live_sharpe`

**Cypher:**
```cypher
MATCH path = (:Dataset)-[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(:Feature)
             -[:USED_IN]->(m:Model)
WHERE m.status = 'Live'
  AND m.live_sharpe < toFloat($threshold)
RETURN path
```

---

### 4. `Datasets costing more than $budget USD`

**Story:** Entry point for the ROI/procurement story — shows expensive datasets and their vendor.

**Parameter:** `$budget` — String (Bloom passes as string, `toInteger()` handles conversion)

**Cypher:**
```cypher
MATCH path = (v:DataVendor)-[:PROVIDES]->(d:Dataset)
WHERE (d.annual_license_cost + d.ingestion_cost) >= toInteger($budget)
RETURN path
```

---

## Scene Actions

Scene actions appear in the right-click context menu on a node. They dynamically expand the graph from the selected node.

> All use `UNWIND $nodes AS eid` + `elementId(n) = eid` — the correct Bloom pattern for multi-node selection.

---

### On Dataset

#### `Full path from dataset to PnL`
Complete lineage from raw data to performance — the "money shot" of the demo.

```cypher
UNWIND $nodes AS eid
MATCH path = (ds:Dataset WHERE elementId(ds)=eid)-[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(:Feature)
             -[:USED_IN]->(:Model)
             -[:POWERS]->(:Strategy)
             -[:PRODUCES]->(:PnL)
RETURN path
```

> Returns all PnL periods. To focus on 2024 only, add `WHERE p.period = '2024-FY'` after binding `(p:PnL)`.

---

#### `What breaks if I lose`
Blast radius — shows all live models and strategies exposed to losing this dataset.

```cypher
UNWIND $nodes AS eid
MATCH path = (ds:Dataset WHERE elementId(ds)=eid)-[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(:Feature)
             -[:USED_IN]->(m:Model)
             -[:POWERS]->(:Strategy)
WHERE m.status = 'Live'
RETURN path
```

---

### On DataVendor

#### `Show full exposure`
Traces everything a vendor's data feeds into — stops at live models.

```cypher
UNWIND $nodes AS eid
MATCH path = (dv:DataVendor WHERE elementId(dv)=eid)-[:PROVIDES]->(:Dataset)
             -[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(:Feature)
             -[:USED_IN]->(m:Model)
WHERE m.status = 'Live'
RETURN path
```

---

### On Model

#### `Features driving`
Shows all datasets and features feeding into this model (in-production features only).

```cypher
UNWIND $nodes AS eid
MATCH path = (:Dataset)-[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(f:Feature)
             -[r:USED_IN]->(m:Model WHERE elementId(m)=eid)
WHERE r.in_production = true
RETURN path
```

---

#### `Show correlated features`
Surfaces redundant feature pairs both used in this model with R² > 0.45.

```cypher
UNWIND $nodes AS eid
MATCH (m:Model WHERE elementId(m)=eid)
MATCH path = (:Dataset)-[:FEEDS]->(:FeaturePipeline)
             -[:GENERATES]->(f1:Feature)-[r:CORRELATED_WITH]->(f2:Feature)
             <-[:GENERATES]-(:FeaturePipeline)<-[:FEEDS]-(:Dataset)
WHERE (f1)-[:USED_IN]->(m) AND (f2)-[:USED_IN]->(m)
  AND r.r_squared > 0.45
RETURN path
```

---

### On Strategy

#### `Show PnL history`
Expands all PnL records for the selected strategy across all periods.

```cypher
UNWIND $nodes AS eid
MATCH path = (s:Strategy WHERE elementId(s)=eid)-[:PRODUCES]->(p:PnL)
RETURN path
```

---

## Indexes

The perspective uses the following indexes (all `ONLINE`):

| Index | Type | Covers |
|---|---|---|
| `bloom_node_search` | FULLTEXT | `name` on all 6 node labels — powers the Bloom search bar |
| `model_status` | RANGE | `Model.status` |
| `pnl_period` | RANGE | `PnL.period` |
| `dataset_active` | RANGE | `Dataset.active` |
| Per-label constraints | RANGE | `id` on every node label |

---

## Suggested Demo Flow

1. **Search bar:** type `"Earnings"` → Bloom returns the `Earnings Call NLP Sentiment` Dataset and `Earnings Call Tone Score` Feature via the fulltext index
2. **Right-click Dataset → `Full path from dataset to PnL`** → reveals the complete lineage graph
3. **Right-click Model → `Show correlated features`** → highlights redundancy with News & Social Media Sentiment
4. **Right-click same Dataset → `What breaks if I lose`** → shows blast radius across live strategies
5. **Search phrase:** `Renewals before 2025-06-01` → surfaces upcoming contracts with vendor context
6. **Search phrase:** `Datasets with MNPI risk above 0.5` → pivots to compliance story
7. **Search phrase:** `Live models with Sharpe below 1.5` → pivots to underperformance / dataset ROI story
