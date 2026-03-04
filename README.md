# Data Asset Intelligence Graph
### A Neo4j Demo for Quantitative Investment Firms

---

## The Problem

A modern quantitative hedge fund spends **millions of dollars per year** on external data. Satellite imagery, credit card transaction feeds, options flow, sentiment signals, ESG scores, macroeconomic nowcasts — the catalog of available **alternative data** has exploded over the past decade.

But most firms have no rigorous answer to a deceptively simple question:

> **"Which of our data purchases are actually making us money?"**

Data procurement decisions are often driven by intuition, vendor relationships, or the loudest researcher in the room. Contracts auto-renew. Duplicate signals accumulate. And when a vendor is discontinued or a dataset goes stale, nobody knows which models — and which live strategies — just lost a critical input.

This is a **data governance, lineage, and ROI attribution problem**. And it is a fundamentally relational one.

---

## Why a Graph?

The relationship between a raw data purchase and a dollar of PnL is not direct. It passes through multiple transformation layers:

```
DataVendor → Dataset → FeaturePipeline → Feature → Model → Strategy → PnL
```

Each hop is a many-to-many relationship:
- One dataset feeds multiple feature pipelines
- One feature is used across multiple models
- One model powers multiple strategies
- One strategy produces PnL across multiple time periods and instruments

A relational database forces you to flatten this into brittle joins. A spreadsheet makes cross-cutting attribution impossible. A **property graph** makes it natural — you traverse the lineage, compute attributions along edges, and answer questions that would otherwise require days of data engineering.

**Three questions this graph answers in seconds:**

| Question | Lens |
|---|---|
| "If this vendor cancels our contract, what breaks?" | Lineage & Dependency |
| "Which datasets have the best risk-adjusted ROI?" | ROI Scoring |
| "Which contracts should we renew, negotiate, or drop?" | Procurement Intelligence |

---

## Graph Model

See [`data-model/SCHEMA.md`](data-model/SCHEMA.md) for full documentation.

```
(DataVendor)-[PROVIDES]->(Dataset)-[FEEDS]->(FeaturePipeline)-[GENERATES]->(Feature)
(Feature)-[USED_IN]->(Model)-[POWERS]->(Strategy)-[PRODUCES]->(PnL)
(Dataset)-[SUBSTITUTABLE_FOR]->(Dataset)
(Feature)-[CORRELATED_WITH]->(Feature)
```

---

## Repo Structure

```
neo4j-data-asset-intelligence/
│
├── README.md                       ← You are here
├── data-model/
│   └── SCHEMA.md                   ← Node & relationship definitions
├── data/
│   ├── seed.ipynb                  ← Jupyter notebook: loads synthetic data into Neo4j
│   └── neo4j-aura-backup.backup    ← Aura database backup (includes NeoDash dashboard node)
├── queries/
│   ├── 01_lineage_impact.cypher    ← Angle 1: dependency & impact analysis
│   ├── 02_roi_scoring.cypher       ← Angle 2: dataset ROI attribution
│   └── 03_renewal_decisions.cypher ← Angle 3: procurement & renewal intelligence
├── bloom/
│   ├── BLOOM_GUIDE.md              ← Perspective config, search phrases & scene actions
│   ├── BLOOM_DEMO_FLOW.md          ← Step-by-step demo script for Bloom
│   └── data asset intel perspective.json  ← Importable Bloom perspective file
└── dashboard/
    ├── DASHBOARD_GUIDE.md          ← NeoDash pages, reports & copy-paste Cypher
    ├── NeoDash_dashboard.json      ← Importable NeoDash dashboard file
    └── Aura_dashboard.json         ← Importable Aura Dashboard file
```

---

## Getting Started

### Prerequisites
- A running **Neo4j AuraDB** instance (or local Neo4j 5.x)
- Python 3.9+ with `neo4j`, `pandas`, `faker` installed
- Neo4j Bloom (available in Aura Console)
- [NeoDash](https://neodash.graphapp.io) (open source, runs in browser — connect to your AuraDB instance) **or** Aura Dashboard (available in the Aura Console)

### Option A — Restore from backup *(fastest)*
1. Clone this repo
2. In the Aura Console, restore `data/neo4j-aura-backup.backup` to your instance — graph data **and** the NeoDash dashboard are included
3. Open NeoDash and connect to your instance — the dashboard loads automatically
4. Open Bloom and import `bloom/data asset intel perspective.json` — then follow `bloom/BLOOM_DEMO_FLOW.md`

### Option B — Fresh seed
1. Clone this repo
2. Open `data/seed.ipynb` in Jupyter, set your AuraDB credentials in the first cell, and run all cells to load the synthetic dataset
3. Load a dashboard:
   - **NeoDash**: connect to your instance → *Load dashboard* → select `dashboard/NeoDash_dashboard.json` — refer to `dashboard/DASHBOARD_GUIDE.md` for report details
   - **Aura Dashboard**: in the Aura Console, import `dashboard/Aura_dashboard.json`
4. Open Bloom and import `bloom/data asset intel perspective.json` — then follow `bloom/BLOOM_DEMO_FLOW.md`
5. Run the Cypher queries in `queries/` from the Aura Console or Neo4j Browser

---

## Key Concepts

**Alternative Data** — Non-traditional data used as inputs to quantitative investment models. Examples: satellite parking lot counts, anonymized credit card spend, web scraping of job postings, shipping AIS data.

**Factor / Feature** — A derived signal computed from raw data. A dataset rarely feeds a model directly; it is first transformed into one or more features (e.g., "30-day momentum of web traffic for retail tickers").

**Data Shapley Value** — A game-theoretic method (based on Shapley values from cooperative game theory) for fairly attributing a model's performance to each of its input features — and by extension, to each upstream dataset.

**Signal Half-Life** — The rate at which a factor's predictive power decays over time, often as the signal becomes crowded by other market participants.

**Total Cost of Data Ownership (TCDO)** — The full cost of a dataset: license fee + ingestion engineering + storage + ongoing data ops + compliance review.

**Alpha Decay** — The degradation of a signal's edge as it becomes widely known and arbitraged away by the market.
