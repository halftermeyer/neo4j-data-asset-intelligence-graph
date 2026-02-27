// ============================================================
// ANGLE 2 — ROI SCORING & DATA ASSET VALUATION
// "Which datasets are earning their keep?"
// ============================================================


// ----------------------------------------------------------
// Q2.1 — Dataset ROI leaderboard
//
// Methodology:
//   1. For each dataset, find all downstream features
//   2. For each feature, sum Shapley values × model live Sharpe
//      × strategy net PnL (most recent year) × model signal weight
//   3. Compute Total Cost of Data Ownership (TCDO)
//   4. ROI = attributed_pnl / tcdo
// ----------------------------------------------------------
MATCH (d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[ui:USED_IN]->(m:Model {status: 'Live'})
      -[pw:POWERS]->(s:Strategy)
      -[:PRODUCES]->(p:PnL {period: '2024-FY'})

WITH d,
     sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m) AS attributed_pnl_usd_m,
     count(DISTINCT m)  AS model_count,
     count(DISTINCT s)  AS strategy_count

WITH d,
     attributed_pnl_usd_m,
     model_count,
     strategy_count,
     (d.annual_license_cost + d.ingestion_cost) AS tcdo_usd

RETURN d.name                                                   AS dataset,
       d.category                                               AS category,
       round(attributed_pnl_usd_m * 1000000) / 1000000         AS attributed_pnl_usd_m,
       tcdo_usd                                                 AS total_cost_usd,
       round((attributed_pnl_usd_m * 1000000) / tcdo_usd * 10) / 10 AS roi_multiple,
       model_count,
       strategy_count,
       d.signal_half_life_days                                  AS signal_half_life_days
ORDER BY roi_multiple DESC;


// ----------------------------------------------------------
// Q2.2 — Feature-level Shapley attribution per model
//         (understand which features drive each model)
// ----------------------------------------------------------
MATCH (d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[ui:USED_IN]->(m:Model)
WHERE ui.in_production = true
RETURN m.name                               AS model,
       m.live_sharpe                        AS live_sharpe,
       f.name                               AS feature,
       f.factor_type                        AS factor_type,
       d.name                               AS source_dataset,
       ui.shapley_value                     AS shapley_value,
       ui.importance_rank                   AS rank
ORDER BY m.name, ui.importance_rank;


// ----------------------------------------------------------
// Q2.3 — Underperforming datasets: high cost, low attribution
//         (candidates for cancellation)
// ----------------------------------------------------------
MATCH (d:Dataset)
OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
                -[:GENERATES]->(f:Feature)
                -[ui:USED_IN]->(m:Model {status: 'Live'})
                -[pw:POWERS]->(s:Strategy)
                -[:PRODUCES]->(p:PnL {period: '2024-FY'})

WITH d,
     coalesce(sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m), 0) AS attributed_pnl_usd_m,
     (d.annual_license_cost + d.ingestion_cost)  AS tcdo_usd

WHERE tcdo_usd > 50000   // Only meaningful spend thresholds
  AND attributed_pnl_usd_m < 5.0

RETURN d.name                AS dataset,
       d.category             AS category,
       d.active               AS is_active,
       tcdo_usd               AS annual_cost_usd,
       round(attributed_pnl_usd_m * 100) / 100 AS attributed_pnl_usd_m,
       '⚠️ Low ROI'           AS flag
ORDER BY tcdo_usd DESC;


// ----------------------------------------------------------
// Q2.4 — Dataset ROI by vendor: which vendors deliver
//         the best bang for buck across their portfolio?
// ----------------------------------------------------------
MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[ui:USED_IN]->(m:Model {status: 'Live'})
      -[pw:POWERS]->(s:Strategy)
      -[:PRODUCES]->(p:PnL {period: '2024-FY'})

WITH v, d,
     sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m) AS dataset_pnl,
     (d.annual_license_cost + d.ingestion_cost)                  AS dataset_cost

WITH v,
     sum(dataset_pnl)   AS total_attributed_pnl_m,
     sum(dataset_cost)  AS total_vendor_spend,
     count(DISTINCT d)  AS active_datasets

RETURN v.name                                                          AS vendor,
       v.tier                                                          AS tier,
       active_datasets,
       total_vendor_spend                                              AS annual_spend_usd,
       round(total_attributed_pnl_m * 100) / 100                      AS attributed_pnl_usd_m,
       round((total_attributed_pnl_m * 1000000) / total_vendor_spend * 10) / 10 AS vendor_roi_multiple
ORDER BY vendor_roi_multiple DESC;


// ----------------------------------------------------------
// Q2.5 — Alpha decay risk: datasets with short signal half-life
//         that are central to live strategies
// ----------------------------------------------------------
MATCH (d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model {status: 'Live'})
      -[:POWERS]->(s:Strategy)
WHERE d.signal_half_life_days <= 30
RETURN d.name                        AS dataset,
       d.signal_half_life_days       AS half_life_days,
       d.annual_license_cost         AS license_cost_usd,
       collect(DISTINCT m.name)      AS live_models,
       collect(DISTINCT s.name)      AS live_strategies,
       '⚡ Short half-life — monitor alpha decay' AS warning
ORDER BY d.signal_half_life_days;
