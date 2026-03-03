// ============================================================
// ANGLE 1 — LINEAGE & DEPENDENCY ANALYSIS
// "What breaks if I lose this dataset?"
// ============================================================


// ----------------------------------------------------------
// Q1.1 — Full lineage path from a specific dataset to PnL
// ----------------------------------------------------------
// Parameters:
//   $dataset_name : string — e.g. "Consumer Credit Card Spend - US"
// ----------------------------------------------------------
:param dataset_name => 'Consumer Credit Card Spend - US'

MATCH path = (d:Dataset)
             -[:FEEDS]->(fp:FeaturePipeline)
             -[:GENERATES]->(f:Feature)
             -[:USED_IN]->(m:Model)
             -[:POWERS]->(s:Strategy)
             -[:PRODUCES]->(p:PnL)
WHERE d.name CONTAINS $dataset_name
RETURN path;


// ----------------------------------------------------------
// Q1.2 — Impact blast radius: which strategies are exposed
//         if a given dataset becomes unavailable?
// ----------------------------------------------------------
// Parameters:
//   $dataset_name : string — e.g. "Consumer Credit Card Spend - US"
// ----------------------------------------------------------
:param dataset_name => 'Consumer Credit Card Spend - US'

MATCH (d:Dataset)
      -[:FEEDS]->(fp:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model)
      -[:POWERS]->(s:Strategy)
WHERE d.name CONTAINS $dataset_name
RETURN d.name                         AS at_risk_dataset,
       collect(DISTINCT fp.name)      AS affected_pipelines,
       collect(DISTINCT f.name)       AS affected_features,
       collect(DISTINCT m.name)       AS affected_models,
       collect(DISTINCT s.name)       AS affected_strategies,
       count(DISTINCT s)              AS strategy_count;


// ----------------------------------------------------------
// Q1.3 — Dataset centrality: which datasets are
//         the most critical (most downstream dependencies)?
// ----------------------------------------------------------
// Parameters:
//   $min_strategy_count : int — minimum strategies to include, e.g. 1
// ----------------------------------------------------------
:param min_strategy_count => 1

MATCH (d:Dataset)
      -[:FEEDS]->(fp:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model)
      -[:POWERS]->(s:Strategy)
WITH d,
     count(DISTINCT fp) AS pipeline_count,
     count(DISTINCT f)  AS feature_count,
     count(DISTINCT m)  AS model_count,
     count(DISTINCT s)  AS strategy_count
WHERE strategy_count >= $min_strategy_count
RETURN d.name                                       AS dataset,
       d.category                                   AS category,
       pipeline_count,
       feature_count,
       model_count,
       strategy_count,
       (model_count + strategy_count)               AS dependency_score
ORDER BY dependency_score DESC;


// ----------------------------------------------------------
// Q1.4 — Single points of failure: datasets with no substitute
//         that feed live models
// ----------------------------------------------------------
// Parameters:
//   $model_status : string — e.g. "Live"
// ----------------------------------------------------------
:param model_status => 'Live'

MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(:Feature)
                  -[:USED_IN]->(m:Model)
WHERE m.status = $model_status
  AND NOT EXISTS {
    MATCH (d)-[:SUBSTITUTABLE_FOR]->(:Dataset)
  }
RETURN d.name                    AS dataset,
       d.category                AS category,
       d.annual_license_cost     AS annual_cost,
       collect(DISTINCT m.name)  AS dependent_live_models,
       'No substitute identified' AS risk_flag
ORDER BY d.annual_license_cost DESC;


// ----------------------------------------------------------
// Q1.5 — Feature redundancy map: highly correlated feature pairs
// ----------------------------------------------------------
// Parameters:
//   $min_r_squared : float — correlation threshold, e.g. 0.45
// ----------------------------------------------------------
:param min_r_squared => 0.45

MATCH (f1:Feature)-[c:CORRELATED_WITH]->(f2:Feature)
WHERE c.r_squared > $min_r_squared
MATCH (d1:Dataset)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(f1)
MATCH (d2:Dataset)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(f2)
RETURN f1.name              AS feature_1,
       f2.name              AS feature_2,
       round(c.r_squared * 100) + '%' AS correlation,
       d1.name              AS source_dataset_1,
       d2.name              AS source_dataset_2,
       CASE WHEN d1.id = d2.id THEN 'Same dataset — definite overlap'
            ELSE 'Different datasets — potential redundancy'
       END                  AS redundancy_type
ORDER BY c.r_squared DESC;


// ----------------------------------------------------------
// Q1.6 — Vendor exposure: total strategy AUM at risk per vendor
// ----------------------------------------------------------
// Parameters:
//   $vendor_tier : string — e.g. "Tier1", "Tier2", or "" for all
// ----------------------------------------------------------
:param vendor_tier => ''

MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(:Feature)
      -[:USED_IN]->(:Model)
      -[:POWERS]->(s:Strategy)
WHERE $vendor_tier = '' OR v.tier = $vendor_tier
RETURN v.name                          AS vendor,
       v.tier                          AS vendor_tier,
       collect(DISTINCT d.name)        AS datasets_provided,
       collect(DISTINCT s.name)        AS strategies_exposed,
       sum(DISTINCT s.aum_usd_m)       AS total_aum_at_risk_usd_m
ORDER BY total_aum_at_risk_usd_m DESC;
