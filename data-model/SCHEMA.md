# Data Model — Schema Reference

## Overview

The graph models the full **data supply chain** of a quantitative hedge fund, from external data vendor contracts down to live strategy PnL. Every node and relationship is designed to support three analytical lenses: lineage impact analysis, ROI attribution, and procurement intelligence.

---

## Node Types

### `DataVendor`
An external company that licenses data to the fund.

| Property | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Vendor name |
| `category` | string | e.g. "Alternative Data", "Market Data", "Macro" |
| `hq_country` | string | Country of headquarters |
| `tier` | string | "Tier1 / Tier2 / Tier3" — reliability rating |

---

### `Dataset`
A specific licensed data product from a vendor.

| Property | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Dataset name |
| `category` | string | e.g. "Satellite", "Credit Card", "Sentiment", "Options Flow" |
| `asset_class_coverage` | string | e.g. "Equities", "Macro", "Multi-Asset" |
| `annual_license_cost` | int | USD per year |
| `ingestion_cost` | int | Annual engineering & infra cost (USD) |
| `signal_half_life_days` | int | Estimated days before alpha decays significantly |
| `mnpi_risk_score` | float | 0–1 score: risk of containing material non-public information |
| `coverage_start_year` | int | Year the dataset history begins |
| `refresh_frequency` | string | "Daily / Weekly / Monthly / Real-time" |
| `active` | boolean | Whether currently licensed |

---

### `FeaturePipeline`
An engineering pipeline that transforms one or more raw datasets into model-ready features.

| Property | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Pipeline name |
| `team_owner` | string | Responsible research/engineering team |
| `compute_cost_annual` | int | Annual cloud compute cost (USD) |
| `language` | string | e.g. "Python", "C++" |

---

### `Feature`
A derived signal produced by a pipeline, used as input to one or more ML models.

| Property | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Feature name |
| `factor_type` | string | e.g. "Momentum", "Value", "Sentiment", "Macro", "Alternative" |
| `coverage_universe` | string | e.g. "US Equities", "European Equities", "Global Macro" |
| `lookback_days` | int | Historical window used to compute the feature |
| `is_proprietary` | boolean | True if derived from exclusive/non-public data |

---

### `Model`
A machine learning or statistical model that consumes features and generates trading signals.

| Property | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Model name |
| `model_type` | string | e.g. "GBM", "Linear Factor", "LSTM", "Ensemble", "Signal Combiner" |
| `asset_class` | string | Primary asset class targeted |
| `backtest_sharpe` | float | Sharpe ratio in backtest |
| `live_sharpe` | float | Sharpe ratio in live trading |
| `inception_year` | int | Year model went live |
| `status` | string | "Live / Research / Deprecated" |

---

### `Strategy`
A live trading strategy powered by one or more models.

| Property | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Strategy name |
| `aum_usd_m` | float | Assets under management (millions USD) |
| `asset_class` | string | Asset class |
| `approach` | string | e.g. "Long/Short Equity", "Statistical Arbitrage", "Global Macro" |
| `target_sharpe` | float | Target Sharpe ratio |
| `inception_year` | int | Year strategy launched |

---

### `PnL`
A PnL record for a strategy over a specific period.

| Property | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `period` | string | e.g. "2023-Q1", "2024-FY" |
| `gross_pnl_usd_m` | float | Gross PnL in millions USD |
| `net_pnl_usd_m` | float | Net PnL after costs |
| `sharpe` | float | Realized Sharpe for the period |
| `max_drawdown_pct` | float | Max drawdown percentage |

---

## Relationship Types

### `(DataVendor)-[PROVIDES]->(Dataset)`
A vendor provides a licensed dataset to the fund.

| Property | Type | Description |
|---|---|---|
| `contract_start` | string | Contract start date |
| `renewal_date` | string | Next renewal date |
| `notice_period_days` | int | Days notice required to cancel |
| `annual_fee_usd` | int | Contracted annual fee |
| `exclusivity` | boolean | Whether the fund has data exclusivity |
| `auto_renew` | boolean | Whether contract auto-renews |

---

### `(Dataset)-[FEEDS]->(FeaturePipeline)`
A dataset is consumed as input by a feature engineering pipeline.

| Property | Type | Description |
|---|---|---|
| `primary_input` | boolean | Whether this is the pipeline's main data source |

---

### `(FeaturePipeline)-[GENERATES]->(Feature)`
A pipeline produces a feature as output.

| Property | Type | Description |
|---|---|---|
| `transformation` | string | e.g. "Z-score normalization", "Rolling window average", "NLP embedding" |

---

### `(Feature)-[USED_IN]->(Model)`
A feature is used as an input to a model.

| Property | Type | Description |
|---|---|---|
| `shapley_value` | float | Data Shapley attribution score (0–1, sums to ~1 per model) |
| `importance_rank` | int | Rank of this feature within the model |
| `in_production` | boolean | Whether feature is active in live model |

---

### `(Model)-[POWERS]->(Strategy)`
A model generates signals that are consumed by a strategy.

| Property | Type | Description |
|---|---|---|
| `signal_weight` | float | Weight of this model's signal in the strategy |
| `since_year` | int | Year this model was integrated into the strategy |

---

### `(Strategy)-[PRODUCES]->(PnL)`
A strategy produces a PnL record for a period.

---

### `(Dataset)-[SUBSTITUTABLE_FOR]->(Dataset)`
Two datasets carry overlapping signals and one could replace the other.

| Property | Type | Description |
|---|---|---|
| `overlap_score` | float | Estimated signal overlap (0–1) |
| `cost_delta_usd` | int | Annual cost difference (positive = substitute is cheaper) |

---

### `(Feature)-[CORRELATED_WITH]->(Feature)`
Two features are statistically correlated, suggesting potential redundancy.

| Property | Type | Description |
|---|---|---|
| `r_squared` | float | R² of correlation in backtest |
| `detected_date` | string | Date redundancy was flagged |
