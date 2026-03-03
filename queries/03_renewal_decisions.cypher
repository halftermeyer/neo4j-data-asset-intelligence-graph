// ============================================================
// ANGLE 3 — PROCUREMENT & RENEWAL INTELLIGENCE
// "Should we renew this contract?"
// ============================================================


// ----------------------------------------------------------
// Q3.1 — Renewal dashboard
// 🎯 KEY DEMO QUERY — run this first
// ----------------------------------------------------------
// Parameters:
//   $days_horizon    : int    — lookahead window, e.g. 90
//   $today           : string — reference date, e.g. "2025-01-01"
//   $period          : string — PnL period for ROI context, e.g. "2024-FY"
// ----------------------------------------------------------
:param days_horizon => 90
:param today        => '2025-01-01'
:param period       => '2024-FY'

MATCH (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)
WHERE date(prov.renewal_date) <= date($today) + duration({days: $days_horizon})
  AND date(prov.renewal_date) >= date($today)

OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
               -[:GENERATES]->(f:Feature)
               -[:USED_IN]->(m:Model {status: 'Live'})
               -[pw:POWERS]->(s:Strategy)
               -[:PRODUCES]->(p:PnL)
WHERE p.period = $period

OPTIONAL MATCH (d)-[sub:SUBSTITUTABLE_FOR]->(alt:Dataset)

WITH v, d, prov,
     coalesce(sum(DISTINCT pw.signal_weight * p.net_pnl_usd_m), 0) AS approx_pnl_exposure_m,
     collect(DISTINCT m.name)   AS live_models,
     collect(DISTINCT s.name)   AS live_strategies,
     collect(DISTINCT alt.name) AS substitutes,
     (d.annual_license_cost + d.ingestion_cost) AS tcdo_usd

RETURN v.name                         AS vendor,
       d.name                         AS dataset,
       prov.renewal_date              AS renewal_date,
       prov.notice_period_days        AS notice_days,
       prov.auto_renew                AS auto_renews,
       prov.annual_fee_usd            AS annual_fee_usd,
       tcdo_usd                       AS total_cost_usd,
       round(approx_pnl_exposure_m * 100) / 100  AS pnl_exposure_usd_m,
       size(live_models)              AS live_model_count,
       live_strategies,
       CASE WHEN size(substitutes) > 0 THEN substitutes
            ELSE ['None identified']
       END                            AS available_substitutes,
       CASE
         WHEN approx_pnl_exposure_m > 10 AND size(substitutes) = 0 THEN '🔴 RENEW — critical, no substitute'
         WHEN approx_pnl_exposure_m > 10 AND size(substitutes) > 0 THEN '🟡 NEGOTIATE — high value but substitute exists'
         WHEN approx_pnl_exposure_m < 2  AND size(substitutes) > 0 THEN '🟢 CONSIDER DROPPING — low ROI, substitute available'
         WHEN approx_pnl_exposure_m < 2  AND size(substitutes) = 0 THEN '🟡 REVIEW — low ROI but no substitute'
         ELSE '🟡 STANDARD RENEWAL'
       END AS recommendation
ORDER BY date(prov.renewal_date);


// ----------------------------------------------------------
// Q3.2 — Full contract inventory with ROI and risk score
// ----------------------------------------------------------
// Parameters:
//   $period      : string — e.g. "2024-FY"
//   $model_status: string — e.g. "Live"
// ----------------------------------------------------------
:param period       => '2024-FY'
:param model_status => 'Live'

MATCH (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)

OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
               -[:GENERATES]->(f:Feature)
               -[ui:USED_IN]->(m:Model)
               -[pw:POWERS]->(s:Strategy)
               -[:PRODUCES]->(p:PnL)
WHERE m.status = $model_status
  AND p.period = $period

OPTIONAL MATCH (d)-[:SUBSTITUTABLE_FOR]->(alt:Dataset)

WITH v, d, prov,
     coalesce(sum(ui.shapley_value * pw.signal_weight * p.net_pnl_usd_m), 0) AS attributed_pnl_m,
     count(DISTINCT m) AS model_count,
     collect(DISTINCT alt.name) AS substitutes,
     (d.annual_license_cost + d.ingestion_cost) AS tcdo_usd

RETURN v.name                         AS vendor,
       d.name                         AS dataset,
       d.category                     AS category,
       d.active                       AS active,
       prov.renewal_date              AS renewal_date,
       prov.auto_renew                AS auto_renew,
       prov.notice_period_days        AS notice_days,
       tcdo_usd                       AS annual_cost_usd,
       round(attributed_pnl_m * 100) / 100              AS attributed_pnl_usd_m,
       CASE WHEN tcdo_usd > 0
            THEN round((attributed_pnl_m * 1000000) / tcdo_usd * 10) / 10
            ELSE 0
       END                            AS roi_multiple,
       model_count                    AS live_models_using,
       CASE WHEN size(substitutes) > 0 THEN substitutes ELSE ['None'] END AS substitutes,
       d.mnpi_risk_score              AS mnpi_risk
ORDER BY prov.renewal_date;


// ----------------------------------------------------------
// Q3.3 — MNPI risk audit
// ----------------------------------------------------------
// Parameters:
//   $min_mnpi_score : float  — e.g. 0.5
//   $model_status   : string — e.g. "Live"
// ----------------------------------------------------------
:param min_mnpi_score => 0.5
:param model_status   => 'Live'

MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model)
      -[:POWERS]->(s:Strategy)
WHERE d.mnpi_risk_score >= $min_mnpi_score
  AND m.status = $model_status
RETURN d.name                         AS dataset,
       d.mnpi_risk_score              AS mnpi_risk_score,
       v.name                         AS vendor,
       collect(DISTINCT m.name)       AS models_using,
       collect(DISTINCT s.name)       AS strategies_using,
       sum(DISTINCT s.aum_usd_m)      AS total_aum_exposed_m,
       '⚠️ Compliance review required' AS flag
ORDER BY d.mnpi_risk_score DESC;


// ----------------------------------------------------------
// Q3.4 — Auto-renew exposure
// ----------------------------------------------------------
// Parameters:
//   $model_status : string — e.g. "Live"
// ----------------------------------------------------------
:param model_status => 'Live'

MATCH (v:DataVendor)-[prov:PROVIDES]->(d:Dataset)
WHERE prov.auto_renew = true
OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)
               -[:GENERATES]->(f:Feature)
               -[ui:USED_IN]->(m:Model)
WHERE m.status = $model_status
WITH v, d, prov, count(DISTINCT m) AS live_model_count
RETURN v.name                         AS vendor,
       d.name                         AS dataset,
       prov.annual_fee_usd            AS annual_fee_usd,
       prov.renewal_date              AS auto_renews_on,
       prov.notice_period_days        AS cancel_by_days_before,
       live_model_count               AS live_models_using,
       '⏰ Will auto-renew — confirm intent' AS action_required
ORDER BY prov.annual_fee_usd DESC;


// ----------------------------------------------------------
// Q3.5 — Substitution opportunity map
// ----------------------------------------------------------
// Parameters:
//   $min_overlap_score   : float — signal overlap threshold, e.g. 0.4
//   $min_saving_usd      : int   — minimum saving to surface, e.g. 50000
//   $model_status        : string — e.g. "Live"
// ----------------------------------------------------------
:param min_overlap_score => 0.4
:param min_saving_usd    => 50000
:param model_status      => 'Live'

MATCH (d:Dataset)-[sub:SUBSTITUTABLE_FOR]->(alt:Dataset)
WHERE sub.overlap_score >= $min_overlap_score
  AND sub.cost_delta_usd >= $min_saving_usd
MATCH (v1:DataVendor)-[:PROVIDES]->(d)
MATCH (v2:DataVendor)-[:PROVIDES]->(alt)

OPTIONAL MATCH (d)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(f:Feature)
               -[:USED_IN]->(m:Model)
WHERE m.status = $model_status

RETURN d.name                          AS current_dataset,
       v1.name                         AS current_vendor,
       d.annual_license_cost           AS current_cost_usd,
       alt.name                        AS substitute_dataset,
       v2.name                         AS substitute_vendor,
       alt.annual_license_cost         AS substitute_cost_usd,
       sub.cost_delta_usd              AS potential_saving_usd,
       round(sub.overlap_score * 100) + '%' AS signal_overlap,
       count(DISTINCT m)               AS live_models_at_risk,
       CASE WHEN sub.overlap_score >= 0.5 AND sub.cost_delta_usd > 100000
            THEN '💡 Strong substitution candidate'
            WHEN sub.overlap_score >= 0.4
            THEN '🔍 Worth evaluating'
            ELSE '⚡ Partial overlap only'
       END                             AS assessment
ORDER BY sub.cost_delta_usd DESC;
