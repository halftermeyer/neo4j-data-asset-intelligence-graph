// ============================================================
// ANGLE 1 — LINEAGE & DEPENDENCY ANALYSIS
// "What breaks if I lose this dataset?"
// ============================================================


// ----------------------------------------------------------
// Q1.1 — Full lineage path from a specific dataset to PnL
// Use: Visualise the dependency chain for any dataset
// ----------------------------------------------------------
MATCH path = (d:Dataset {name: 'Consumer Credit Card Spend - US'})
             -[:FEEDS]->(fp:FeaturePipeline)
             -[:GENERATES]->(f:Feature)
             -[:USED_IN]->(m:Model)
             -[:POWERS]->(s:Strategy)
             -[:PRODUCES]->(p:PnL)
RETURN path;


// ----------------------------------------------------------
// Q1.2 — Impact blast radius: which strategies are exposed
//         if a given dataset becomes unavailable?
// ----------------------------------------------------------
MATCH (d:Dataset {name: 'Consumer Credit Card Spend - US'})
      -[:FEEDS]->(fp:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model)
      -[:POWERS]->(s:Strategy)
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
MATCH (d:Dataset)
      -[:FEEDS]->(fp:FeaturePipeline)
      -[:GENERATES]->(f:Feature)
      -[:USED_IN]->(m:Model)
      -[:POWERS]->(s:Strategy)
RETURN d.name                          AS dataset,
       d.category                      AS category,
       count(DISTINCT fp)              AS pipeline_count,
       count(DISTINCT f)               AS feature_count,
       count(DISTINCT m)               AS model_count,
       count(DISTINCT s)               AS strategy_count,
       (count(DISTINCT m) + count(DISTINCT s)) AS dependency_score
ORDER BY dependency_score DESC;


// ----------------------------------------------------------
// Q1.4 — Single points of failure: datasets with no substitute
//         that feed live models
// ----------------------------------------------------------
MATCH (d:Dataset)-[:FEEDS]->(:FeaturePipeline)-[:GENERATES]->(:Feature)
                  -[:USED_IN]->(m:Model {status: 'Live'})
WHERE NOT EXISTS {
    MATCH (d)-[:SUBSTITUTABLE_FOR]->(:Dataset)
}
RETURN d.name               AS dataset,
       d.category            AS category,
       d.annual_license_cost AS annual_cost,
       collect(DISTINCT m.name) AS dependent_live_models,
       'No substitute identified' AS risk_flag
ORDER BY d.annual_license_cost DESC;


// ----------------------------------------------------------
// Q1.5 — Feature redundancy map: highly correlated feature pairs
//         and their shared upstream datasets
// ----------------------------------------------------------
MATCH (f1:Feature)-[c:CORRELATED_WITH]->(f2:Feature)
WHERE c.r_squared > 0.45
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
// Q1.6 — Vendor exposure summary: total strategy AUM
//         at risk per vendor
// ----------------------------------------------------------
MATCH (v:DataVendor)-[:PROVIDES]->(d:Dataset)
      -[:FEEDS]->(:FeaturePipeline)
      -[:GENERATES]->(:Feature)
      -[:USED_IN]->(:Model)
      -[:POWERS]->(s:Strategy)
RETURN v.name                          AS vendor,
       v.tier                          AS vendor_tier,
       collect(DISTINCT d.name)        AS datasets_provided,
       collect(DISTINCT s.name)        AS strategies_exposed,
       sum(DISTINCT s.aum_usd_m)       AS total_aum_at_risk_usd_m
ORDER BY total_aum_at_risk_usd_m DESC;
