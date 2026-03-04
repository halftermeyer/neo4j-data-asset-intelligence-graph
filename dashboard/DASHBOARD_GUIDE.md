# NeoDash Dashboard Guide — Data Asset Intelligence Graph

**Pages:** 5
**Drill-down parameter:** `neodash_dataset_name` (set via report action on Page 3)

---

## Loading the Dashboard

Three options:

| Method | How |
|---|---|
| **From backup** | Restore `data/neo4j-aura-backup.backup` in the Aura Console — the dashboard is persisted as a node and loads automatically in NeoDash |
| **NeoDash manual import** | In NeoDash, connect to your instance → *Load dashboard* → select `dashboard/NeoDash_dashboard.json` |
| **Aura Dashboard import** | In the Aura Console, import `dashboard/Aura_dashboard.json` |

---

## NeoDash Setup Notes

- In every **Select** report: set the *Parameter name* field in the report settings to the parameter listed.
- Parameter values set by a selector persist as you navigate between pages within the same session.
- **Report actions** (drill-down): on any Table report, open *Report actions → On Click → Set Parameter*, map the column name to the target parameter, then optionally add *Navigate to page*.
- **Graph reports**: return `path` or a mix of nodes + relationships; NeoDash renders them automatically.
- Recommended layout: **2 columns** for KPI rows, **full width** for tables and graphs.

---

## Page 1 — Portfolio Overview

High-level KPIs and model/strategy health. Starting point for any audience. The two selectors here (`neodash_pnl_period` and `neodash_model_status`) are placed first so their values are set before navigating to any other page.

---

### Report 1.1 — PnL Period Selector

**Type:** Select — Node Property
**Parameter name:** `neodash_pnl_period`
**Default:** `2024-FY`

```cypher
MATCH (n:`PnL`)
WHERE toLower(toString(n.`period`)) CONTAINS toLower($input)
RETURN DISTINCT n.`period` AS value, n.`period` AS display
ORDER BY size(toString(value)) ASC
LIMIT 5
```

---

### Report 1.2 — Model Status Selector

**Type:** Select — Node Property
**Parameter name:** `neodash_model_status`
**Multi-select:** yes — stored as a list; all queries use `IN $neodash_model_status`
**Default:** `Live`

```cypher
MATCH (n:`Model`)
WHERE toLower(toString(n.`status`)) CONTAINS toLower($input)
RETURN DISTINCT n.`status` AS value, n.`status` AS display
ORDER BY size(toString(value)) ASC
LIMIT 5
```

---

### Report 1.3 — Total AUM

**Type:** Number
**Description:** Sum of AUM across all live strategies.

```cypher
MATCH (s:Strategy)
RETURN sum(s.aum_usd_m) AS Total_AUM_USD_M
```

---

### Report 1.4 — Total Annual Data Spend

**Type:** Number
**Description:** Sum of license + ingestion cost across all active datasets.

```cypher
MATCH (d:Dataset)
WHERE d.active = true
RETURN sum(d.annual_license_cost + d.ingestion_cost) AS Annual_Data_Spend_USD
```

---

### Report 1.5 — Live Model Count

**Type:** Number

```cypher
MATCH (m:Model)
WHERE m.status IN $neodash_model_status
RETURN count(m) AS Live_Models
```

---

### Report 1.6 — Live Model Scorecard

**Type:** Table
**Description:** Per-model Sharpe comparison and decay between backtest and live.
**Parameters used:** `$neodash_model_status`

```cypher
MATCH (m:Model)
WHERE m.status IN $neodash_model_status
OPTIONAL MATCH (f:Feature)-[ui:USED_IN]->(m)
WHERE ui.in_production = true
WITH m, count(DISTINCT f) AS features_in_production
RETURN m.name                                             AS model,
       m.model_type                                       AS type,
       m.asset_class                                      AS asset_class,
       m.backtest_sharpe                                  AS backtest_sharpe,
       m.live_sharpe                                      AS live_sharpe,
       round((m.backtest_sharpe - m.live_sharpe) * 100) / 100 AS sharpe_decay,
       features_in_production,
       m.inception_year                                   AS live_since
ORDER BY m.live_sharpe DESC
```

---

### Report 1.7 — Strategy AUM

**Type:** Bar Chart
**X-axis:** `strategy`  **Y-axis:** `aum_usd_m`

```cypher
MATCH (s:Strategy)
RETURN s.name     AS strategy,
       s.aum_usd_m AS aum_usd_m
ORDER BY s.aum_usd_m DESC
```

---

### Report 1.8 — Strategy PnL

**Type:** Table
**Description:** PnL for the selected period.
**Parameters used:** `$neodash_pnl_period`

```cypher
MATCH (s:Strategy)-[:PRODUCES]->(p:PnL)
WHERE p.period = $neodash_pnl_period
RETURN s.name              AS strategy,
       s.approach           AS approach,
       s.aum_usd_m          AS aum_usd_m,
       p.gross_pnl_usd_m    AS gross_pnl_usd_m,
       p.net_pnl_usd_m      AS net_pnl_usd_m,
       p.sharpe             AS period_sharpe,
       p.max_drawdown_pct   AS max_drawdown_pct
ORDER BY p.net_pnl_usd_m DESC
```

---

## Page 2 — Procurement & Renewals

Answers: *"What contracts are coming up? Should we renew?"*

---

### Report 2.1 — Reference Date Selector

**Type:** Select — Date Picker
**Parameter name:** `neodash_today`
**Default:** `2025-01-01`
**Description:** Reference date for the renewal window. NeoDash stores this as a date object; the `date()` function in Cypher handles it directly.

```cypher
RETURN true;
```

---

### Report 2.2 — Lookahead Window (days)

**Type:** Select — Custom Query (free text input)
**Parameter name:** `neodash_days_horizon`
**Default:** `90`
**Description:** User types an integer; `toInteger()` in the main query handles conversion.

```cypher
RETURN coalesce(toInteger($input), 90)
```

---

### Report 2.3 — Renewal Dashboard

**Type:** Table
**Description:** Contracts renewing within the lookahead window, with ROI context and a recommendation.
**Parameters used:** `$neodash_today`, `$neodash_days_horizon`, `$neodash_pnl_period`
**Report action:** Click row → set `neodash_dataset_name` to column `dataset` → navigate to Page 5 (Dataset Drill-down)

```cypher
MATCH (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)
WHERE date(prov.renewal_date) >= date($neodash_today)
  AND date(prov.renewal_date) <= date($neodash_today) + duration({days: toInteger($neodash_days_horizon)})

OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
               -[:GENERATES]->(f:Feature)
               -[:USED_IN]->(m:Model {status: 'Live'})
               -[pw:POWERS]->(s:Strategy)
               -[:PRODUCES]->(p:PnL)
WHERE p.period = $neodash_pnl_period

OPTIONAL MATCH (d)-[sub:SUBSTITUTABLE_FOR]->(alt:Dataset)

WITH v, d, prov,
     coalesce(sum(DISTINCT pw.signal_weight * p.net_pnl_usd_m), 0) AS approx_pnl_exposure_m,
     collect(DISTINCT m.name)   AS live_models,
     collect(DISTINCT s.name)   AS live_strategies,
     collect(DISTINCT alt.name) AS substitutes,
     (d.annual_license_cost + d.ingestion_cost) AS tcdo_usd

RETURN v.name                  AS vendor,
       d.name                  AS dataset,
       prov.renewal_date       AS renewal_date,
       prov.notice_period_days AS notice_days,
       prov.auto_renew         AS auto_renews,
       prov.annual_fee_usd     AS annual_fee_usd,
       tcdo_usd                AS total_cost_usd,
       round(approx_pnl_exposure_m * 100) / 100 AS pnl_exposure_usd_m,
       size(live_models)       AS live_model_count,
       live_strategies,
       CASE WHEN size(substitutes) > 0 THEN substitutes
            ELSE ['None identified']
       END                     AS available_substitutes,
       CASE
         WHEN approx_pnl_exposure_m > 10 AND size(substitutes) = 0 THEN 'RENEW — critical, no substitute'
         WHEN approx_pnl_exposure_m > 10 AND size(substitutes) > 0 THEN 'NEGOTIATE — high value, substitute exists'
         WHEN approx_pnl_exposure_m < 2  AND size(substitutes) > 0 THEN 'CONSIDER DROPPING — low ROI, substitute available'
         WHEN approx_pnl_exposure_m < 2  AND size(substitutes) = 0 THEN 'REVIEW — low ROI, no substitute'
         ELSE 'STANDARD RENEWAL'
       END                     AS recommendation
ORDER BY date(prov.renewal_date)
```

---

### Report 2.4 — Auto-renew Exposure

**Type:** Table
**Description:** All contracts that will auto-renew unless cancelled. Ordered by fee, highest risk first.
**Parameters used:** `$neodash_model_status`
**Report action:** Click `dataset` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)
WHERE prov.auto_renew = true
OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
               -[:GENERATES]->(f:Feature)
               -[:USED_IN]->(m:Model)
WHERE m.status IN $neodash_model_status
WITH v, d, prov, count(DISTINCT m) AS live_model_count
RETURN v.name                 AS vendor,
       d.name                 AS dataset,
       prov.annual_fee_usd    AS annual_fee_usd,
       prov.renewal_date      AS auto_renews_on,
       prov.notice_period_days AS cancel_by_days_before,
       live_model_count,
       'Will auto-renew — confirm intent' AS action_required
ORDER BY prov.annual_fee_usd DESC
```

---

### Report 2.5 — Top Datasets by Total Cost

**Type:** Table
**Description:** Visual snapshot of where the data budget goes. The `has_substitute` column reveals whether a cheaper alternative exists.
**Report action:** Click `dataset` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
OPTIONAL MATCH (d)-[:SUBSTITUTABLE_FOR]->(alt:Dataset)
WITH d, v, collect(alt.name) AS substitutes
RETURN d.name                AS dataset,
       v.name                AS vendor,
       (d.annual_license_cost + d.ingestion_cost) AS total_cost_usd,
       CASE WHEN size(substitutes) > 0 THEN 'Has substitute' ELSE 'No substitute' END AS has_substitute
ORDER BY total_cost_usd DESC
LIMIT 15
```

---

### Report 2.6 — Substitution Opportunity Map

**Type:** Table
**Description:** Dataset pairs where a cheaper substitute exists with meaningful signal overlap.

```cypher
MATCH (d:Dataset)-[sub:SUBSTITUTABLE_FOR]->(alt:Dataset)
WHERE sub.overlap_score >= 0.4
  AND sub.cost_delta_usd >= 50000
MATCH (v1:DataVendor)-[:PROVIDES]->(d)
MATCH (v2:DataVendor)-[:PROVIDES]->(alt)
OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(:Feature)
               -[:USED_IN]->(m:Model {status: 'Live'})
RETURN d.name                 AS current_dataset,
       v1.name                AS current_vendor,
       d.annual_license_cost  AS current_cost_usd,
       alt.name               AS substitute_dataset,
       v2.name                AS substitute_vendor,
       alt.annual_license_cost AS substitute_cost_usd,
       sub.cost_delta_usd     AS potential_saving_usd,
       round(sub.overlap_score * 100) + '%' AS signal_overlap,
       count(DISTINCT m)      AS live_models_at_risk,
       CASE
         WHEN sub.overlap_score >= 0.5 AND sub.cost_delta_usd > 100000 THEN 'Strong substitution candidate'
         ELSE 'Worth evaluating'
       END                    AS assessment
ORDER BY sub.cost_delta_usd DESC
```

---

## Page 3 — ROI Attribution

Answers: *"Which datasets are earning their keep?"*

---

### Report 3.1 — Dataset ROI Leaderboard

**Type:** Bar Chart
**X-axis:** `dataset`  **Y-axis:** `roi_multiple`
**Parameters used:** `$neodash_pnl_period`, `$neodash_model_status`

```cypher
MATCH (d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[ui:USED_IN]->(m:Model)
      -[pw:POWERS]->(s:Strategy)
      -[:PRODUCES]->(p:PnL)
WHERE m.status IN $neodash_model_status
  AND p.period = $neodash_pnl_period
WITH d,
     sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m) AS attributed_pnl_usd_m,
     (d.annual_license_cost + d.ingestion_cost) AS tcdo_usd
RETURN d.name AS dataset,
       round((attributed_pnl_usd_m * 1000000) / tcdo_usd * 10) / 10 AS roi_multiple
ORDER BY roi_multiple DESC
LIMIT 12
```

---

### Report 3.2 — Full Dataset ROI Table

**Type:** Table
**Parameters used:** `$neodash_pnl_period`, `$neodash_model_status`
**Report action:** Click row → set `neodash_dataset_name` to column `dataset` → navigate to Page 5 (Dataset Drill-down)

```cypher
MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
               -[:GENERATES]->(f:Feature)
               -[ui:USED_IN]->(m:Model)
               -[pw:POWERS]->(s:Strategy)
               -[:PRODUCES]->(p:PnL)
WHERE m.status IN $neodash_model_status
  AND p.period = $neodash_pnl_period
OPTIONAL MATCH (d)-[:SUBSTITUTABLE_FOR]->(alt:Dataset)
WITH v, d,
     coalesce(sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m), 0) AS attributed_pnl_m,
     count(DISTINCT m) AS model_count,
     collect(DISTINCT alt.name) AS substitutes,
     (d.annual_license_cost + d.ingestion_cost) AS tcdo_usd
RETURN v.name    AS vendor,
       d.name    AS dataset,
       d.category AS category,
       tcdo_usd  AS annual_cost_usd,
       round(attributed_pnl_m * 100) / 100 AS attributed_pnl_usd_m,
       CASE WHEN tcdo_usd > 0
            THEN round((attributed_pnl_m * 1000000) / tcdo_usd * 10) / 10
            ELSE 0
       END       AS roi_multiple,
       model_count AS live_models_using,
       CASE WHEN size(substitutes) > 0 THEN substitutes ELSE ['None'] END AS substitutes,
       d.mnpi_risk_score AS mnpi_risk,
       d.signal_half_life_days AS half_life_days
ORDER BY roi_multiple DESC
```

---

### Report 3.3 — Vendor ROI Summary

**Type:** Table
**Parameters used:** `$neodash_pnl_period`, `$neodash_model_status`

```cypher
MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[ui:USED_IN]->(m:Model)
      -[pw:POWERS]->(s:Strategy)
      -[:PRODUCES]->(p:PnL)
WHERE m.status IN $neodash_model_status
  AND p.period = $neodash_pnl_period
WITH v,
     sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m) AS total_pnl_m,
     sum(DISTINCT (d.annual_license_cost + d.ingestion_cost))    AS total_spend,
     count(DISTINCT d) AS datasets
RETURN v.name  AS vendor,
       v.tier  AS tier,
       datasets,
       total_spend AS annual_spend_usd,
       round(total_pnl_m * 100) / 100 AS attributed_pnl_usd_m,
       round((total_pnl_m * 1000000) / total_spend * 10) / 10 AS vendor_roi_multiple
ORDER BY vendor_roi_multiple DESC
```

---

### Report 3.4 — Feature Shapley Attribution

**Type:** Table
**Description:** Which features (and by extension, which datasets) drive model performance. Shows all in-production features across live models.
**Report action:** Click `source_dataset` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[ui:USED_IN]->(m:Model)
WHERE ui.in_production = true
  AND m.status IN $neodash_model_status
RETURN f.name         AS feature,
       f.factor_type  AS factor_type,
       d.name         AS source_dataset,
       m.name         AS model,
       ui.shapley_value AS shapley_value,
       ui.importance_rank AS rank
ORDER BY ui.shapley_value DESC
LIMIT 20
```

---

### Report 3.5 — Underperforming Datasets (High Cost, Low ROI)

**Type:** Table
**Parameters used:** `$neodash_pnl_period`
**Report action:** Click `dataset` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (d:Dataset)
OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
               -[:GENERATES]->(f:Feature)
               -[ui:USED_IN]->(m:Model {status: 'Live'})
               -[pw:POWERS]->(s:Strategy)
               -[:PRODUCES]->(p:PnL)
WHERE p.period = $neodash_pnl_period
WITH d,
     coalesce(sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m), 0) AS attributed_pnl_m,
     (d.annual_license_cost + d.ingestion_cost) AS tcdo_usd
WHERE tcdo_usd >= 50000
  AND attributed_pnl_m < 5.0
RETURN d.name    AS dataset,
       d.category AS category,
       d.active  AS is_active,
       tcdo_usd  AS annual_cost_usd,
       round(attributed_pnl_m * 100) / 100 AS attributed_pnl_usd_m,
       'Low ROI — review or drop' AS flag
ORDER BY tcdo_usd DESC
```

---

## Page 4 — Risk & Compliance

Answers: *"What's our regulatory exposure? Are we paying for duplicate signals?"*

---

### Report 4.1 — Datasets with MNPI Risk ≥ 0.5 (KPI)

**Type:** Number
**Description:** Count of high-MNPI datasets actively feeding live models.

```cypher
MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(:Feature)
      -[:USED_IN]->(m:Model {status: 'Live'})
WHERE d.mnpi_risk_score >= 0.5
RETURN count(DISTINCT d) AS High_MNPI_Datasets
```

---

### Report 4.2 — AUM Exposed to High-MNPI Data (KPI)

**Type:** Number

```cypher
MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(:Feature)
      -[:USED_IN]->(m:Model {status: 'Live'})
      -[:POWERS]->(s:Strategy)
WHERE d.mnpi_risk_score >= 0.5
RETURN sum(DISTINCT s.aum_usd_m) AS AUM_Exposed_to_MNPI_USD_M
```

---

### Report 4.3 — MNPI Risk Audit

**Type:** Table
**Parameters used:** `$neodash_model_status`
**Report action:** Click `dataset` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model)
      -[:POWERS]->(s:Strategy)
WHERE d.mnpi_risk_score >= 0.5
  AND m.status IN $neodash_model_status
RETURN d.name                          AS dataset,
       d.mnpi_risk_score               AS mnpi_risk_score,
       v.name                          AS vendor,
       collect(DISTINCT m.name)        AS models_using,
       collect(DISTINCT s.name)        AS strategies_using,
       sum(DISTINCT s.aum_usd_m)       AS total_aum_exposed_m,
       'Compliance review required'    AS flag
ORDER BY d.mnpi_risk_score DESC
```

---

### Report 4.4 — Single Points of Failure

**Type:** Table
**Description:** Datasets feeding live models with no identified substitute.
**Parameters used:** `$neodash_model_status`
**Report action:** Click `dataset` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(:Feature)
      -[:USED_IN]->(m:Model)
WHERE m.status IN $neodash_model_status
  AND NOT EXISTS { MATCH (d)-[:SUBSTITUTABLE_FOR]->(:Dataset) }
WITH d, collect(DISTINCT m.name) AS dependent_models
RETURN d.name                AS dataset,
       d.category            AS category,
       d.annual_license_cost AS license_cost_usd,
       d.mnpi_risk_score     AS mnpi_risk,
       dependent_models,
       size(dependent_models) AS model_count,
       'No substitute identified' AS risk_flag
ORDER BY d.annual_license_cost DESC
```

---

### Report 4.5 — Correlated Feature Pairs

**Type:** Table
**Description:** Feature pairs with R² > 0.45 that are both active in the same live model — potential duplicate signal spend.
**Report actions:** Click `source_dataset_1` → set `neodash_dataset_name` → navigate to Page 5; Click `source_dataset_2` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (f1:Feature)-[c:CORRELATED_WITH]->(f2:Feature)
WHERE c.r_squared > 0.45
MATCH (d1:Dataset)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(f1)
MATCH (d2:Dataset)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(f2)
MATCH (m:Model {status: 'Live'})
WHERE (f1)-[:USED_IN]->(m) AND (f2)-[:USED_IN]->(m)
RETURN m.name    AS model,
       f1.name   AS feature_1,
       f2.name   AS feature_2,
       round(c.r_squared * 100) + '%' AS r_squared,
       d1.name   AS source_dataset_1,
       d2.name   AS source_dataset_2,
       CASE WHEN d1.name = d2.name
            THEN 'Same dataset — definite overlap'
            ELSE 'Different datasets — potential redundancy'
       END       AS redundancy_type,
       c.detected_date AS detected
ORDER BY c.r_squared DESC
```

---

### Report 4.6 — Alpha Decay Watch

**Type:** Table
**Description:** Datasets with short signal half-life feeding live models — highest risk of alpha crowding.
**Report action:** Click `dataset` → set `neodash_dataset_name` → navigate to Page 5

```cypher
MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model {status: 'Live'})
      -[:POWERS]->(s:Strategy)
WHERE d.signal_half_life_days <= 30
RETURN d.name                    AS dataset,
       d.signal_half_life_days   AS half_life_days,
       d.annual_license_cost     AS license_cost_usd,
       collect(DISTINCT m.name)  AS live_models,
       collect(DISTINCT s.name)  AS live_strategies,
       'Short half-life — monitor alpha decay' AS warning
ORDER BY d.signal_half_life_days
```

---

## Page 5 — Dataset Drill-down

**Entry point:** Click a `dataset` column in any table on Pages 2–4, or a `source_dataset` column in Report 3.4 or 4.5. These report actions set `neodash_dataset_name` and navigate here.
**Parameters used:** `$neodash_dataset_name`, `$neodash_pnl_period`, `$neodash_model_status`

> If arriving directly (not via report action), use Report 5.6 (Dataset Selector) at the bottom of the page.

---

### Report 5.6 — Dataset Selector

**Type:** Select — Node Property
**Parameter name:** `neodash_dataset_name`
**Description:** Manual entry point for this page when not arriving via a report action click.

```cypher
MATCH (n:`Dataset`)
WHERE toLower(toString(n.`name`)) CONTAINS toLower($input)
RETURN DISTINCT n.`name` AS value, n.`name` AS display
ORDER BY size(toString(value)) ASC
LIMIT 5
```

---

### Report 5.1 — Dataset Profile

**Type:** Table
**Description:** Key properties of the selected dataset and its contract.

```cypher
MATCH (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)
WHERE d.name = $neodash_dataset_name
RETURN d.name                  AS dataset,
       v.name                  AS vendor,
       v.tier                  AS vendor_tier,
       d.category              AS category,
       d.asset_class_coverage  AS asset_class,
       d.annual_license_cost   AS license_cost_usd,
       d.ingestion_cost        AS ingestion_cost_usd,
       (d.annual_license_cost + d.ingestion_cost) AS total_cost_usd,
       d.mnpi_risk_score       AS mnpi_risk,
       d.signal_half_life_days AS half_life_days,
       d.refresh_frequency     AS refresh,
       prov.renewal_date       AS renewal_date,
       prov.auto_renew         AS auto_renews,
       prov.notice_period_days AS notice_days,
       prov.annual_fee_usd     AS contracted_fee_usd,
       d.active                AS active
```

---

### Report 5.2 — Full Lineage Graph

**Type:** Graph
**Description:** Complete path from selected dataset to PnL — the lineage money shot.

```cypher
MATCH path = (d:Dataset)-[:FEEDS]->(fp:FeaturePipeline)
             -[:GENERATES]->(f:Feature)
             -[:USED_IN]->(m:Model)
             -[:POWERS]->(s:Strategy)
             -[:PRODUCES]->(p:PnL)
WHERE d.name = $neodash_dataset_name
  AND p.period = $neodash_pnl_period
RETURN path
```

---

### Report 5.3 — Blast Radius (Live Models Only)

**Type:** Table
**Description:** What stops working if this dataset disappears.
**Parameters used:** `$neodash_dataset_name`, `$neodash_model_status`

```cypher
MATCH (d:Dataset)-[:FEEDS]->(fp:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model)
      -[:POWERS]->(s:Strategy)
WHERE d.name = $neodash_dataset_name
  AND m.status IN $neodash_model_status
RETURN d.name                      AS at_risk_dataset,
       collect(DISTINCT fp.name)   AS affected_pipelines,
       collect(DISTINCT f.name)    AS affected_features,
       collect(DISTINCT m.name)    AS affected_models,
       collect(DISTINCT s.name)    AS affected_strategies,
       count(DISTINCT s)           AS strategy_count
```

---

### Report 5.4 — Feature Attribution for This Dataset

**Type:** Table
**Description:** Features derived from this dataset and their Shapley values in each model.
**Parameters used:** `$neodash_dataset_name`, `$neodash_model_status`

```cypher
MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[ui:USED_IN]->(m:Model)
WHERE d.name = $neodash_dataset_name
  AND ui.in_production = true
  AND m.status IN $neodash_model_status
RETURN f.name          AS feature,
       f.factor_type   AS factor_type,
       m.name          AS model,
       ui.shapley_value AS shapley_value,
       ui.importance_rank AS rank
ORDER BY ui.shapley_value DESC
```

---

### Report 5.5 — Substitutes Available

**Type:** Table
**Description:** Alternative datasets that could replace this one, with cost delta and signal overlap.

```cypher
MATCH (d:Dataset)-[sub:SUBSTITUTABLE_FOR]->(alt:Dataset)
WHERE d.name = $neodash_dataset_name
MATCH (v2:DataVendor)-[:PROVIDES]->(alt)
RETURN alt.name                AS substitute_dataset,
       v2.name                 AS substitute_vendor,
       alt.annual_license_cost AS substitute_cost_usd,
       sub.cost_delta_usd      AS potential_saving_usd,
       round(sub.overlap_score * 100) + '%' AS signal_overlap,
       CASE
         WHEN sub.overlap_score >= 0.5 AND sub.cost_delta_usd > 100000
              THEN 'Strong candidate'
         ELSE 'Worth evaluating'
       END                     AS assessment
ORDER BY sub.overlap_score DESC
```

---

## Report Action Reference

> In NeoDash, the variable name entered in the UI omits the `neodash_` prefix — type `dataset_name`, which becomes `$neodash_dataset_name` in queries. To configure: open the report → **...** menu → **Report actions** → **Add action** → type: *Set parameter*, field: `<column>`, variable: `dataset_name` → add a second action: *Navigate*, page: *Dataset Drill-down*.

| Source report | Click column | Sets `neodash_dataset_name` to | Navigates to |
|---|---|---|---|
| 2.3 Renewal Dashboard | `dataset` | `dataset` value | Page 5 |
| 2.4 Auto-renew Exposure | `dataset` | `dataset` value | Page 5 |
| 2.5 Top Datasets by Cost | `dataset` | `dataset` value | Page 5 |
| 3.2 Full Dataset ROI Table | `dataset` | `dataset` value | Page 5 |
| 3.4 Feature Shapley | `source_dataset` | `source_dataset` value | Page 5 |
| 3.5 Underperforming Datasets | `dataset` | `dataset` value | Page 5 |
| 4.3 MNPI Risk Audit | `dataset` | `dataset` value | Page 5 |
| 4.4 Single Points of Failure | `dataset` | `dataset` value | Page 5 |
| 4.5 Correlated Features | `source_dataset_1` | `source_dataset_1` value | Page 5 |
| 4.5 Correlated Features | `source_dataset_2` | `source_dataset_2` value | Page 5 |
| 4.6 Alpha Decay Watch | `dataset` | `dataset` value | Page 5 |

---

## Parameter Reference

| Parameter | Type | Set by | Default | Used on |
|---|---|---|---|---|
| `neodash_pnl_period` | string | Select — Node Property (Report 1.1) | `2024-FY` | Pages 1–5 |
| `neodash_model_status` | **list** (multi-select) | Select — Node Property (Report 1.2) | `["Live"]` | Pages 1–5 |
| `neodash_today` | date object | Select — Date Picker (Report 2.1) | `2025-01-01` | Page 2 |
| `neodash_days_horizon` | integer | Select — Custom Query / free text (Report 2.2) | `90` | Page 2 |
| `neodash_dataset_name` | string | Report action (any page) or Select — Node Property (Report 5.6) | *(none)* | Page 5 |

> **Note:** NeoDash has no global parameter mechanism. Values set by a selector persist in the session state as you navigate — set `neodash_pnl_period` and `neodash_model_status` on Page 1 before switching pages.

> **PnL node caption in graph (Report 5.2):** The graph report's node label settings currently show `PnL: "id"`. Consider changing this to `PnL: "period"` in the graph report's node label configuration so PnL nodes display their period label instead of the internal id.
