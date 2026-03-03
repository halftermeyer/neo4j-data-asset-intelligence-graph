# Bloom Demo Flow — Data Asset Intelligence Graph

**Audience:** Head of Data, Quant PM, COO, Compliance
**Duration:** ~15 minutes
**Prerequisite:** Perspective imported, database connected, blank scene open

---

## Setup before you present

- Import `data asset intel perspective.json`
- Open a **blank scene** (not "Explore all")
- Keep the search bar focused — it's your entry point for every act

---

## Act 1 — "Where does our data actually go?"

**Narrative:** Most firms can't answer this. We can show the full journey from raw vendor data to live PnL in three clicks.

---

**Step 1.** Type `Earnings` in the search bar.

> Bloom returns two nodes instantly: **Earnings Call NLP Sentiment** (Dataset) and **Earnings Call Tone Score** (Feature).
> Point out: this works because of the fulltext index across all node labels.

---

**Step 2.** Click the **Earnings Call NLP Sentiment** Dataset to select it. Right-click → **Scene actions** → **Full path from dataset to PnL**.

> The full graph unfolds: Dataset → Pipeline → Features → Models → Strategies → PnL records.
> Talking point: *"This dataset from SentimentLab feeds four live models and touches every strategy we run. One vendor outage affects $3.1B in AUM."*

> **Layout:** Switch from Force-based to **Hierarchical layout** using the layout bar at the bottom-right of the view — the left-to-right flow from vendor to PnL becomes immediately readable.

---

**Step 3.** Right-click **AlphaBlend US Equity** (Model) → **Scene actions** → **Features driving**.

> Zooms into the feature-level attribution. Point out `shapley_value` on the USED_IN edges.
> Talking point: *"Retail Footfall Momentum is the #1 signal driver at 22% Shapley value — that's OrbitalView satellite data. Consumer Credit Card Spend is #2 at 19%."*

---

**Step 4.** Right-click **AlphaBlend US Equity** again → **Scene actions** → **Show correlated features**.

> Surfaces the correlated pair: Earnings Call Tone Score ↔ News Sentiment Momentum (R² = 0.61).
> Talking point: *"These two features are 61% correlated and come from two different vendor datasets. We may be paying for the same signal twice."*

---

## Act 2 — "What happens if we lose a dataset?"

**Narrative:** Procurement decisions get made without visibility into downstream risk. Let's change that.

---

**Step 5.** Clear the scene. Type `Nowcast` in the search bar → select **Nowcast GDP & Inflation - G20**.

Right-click → **Scene actions** → **What breaks if I lose**.

> Graph shows: 2 pipelines, 5 features, 2 live models (Global Macro Rotator, StatArb European Equities), 2 strategies (Atlas Global Macro, Vega European StatArb).
> Talking point: *"This MacroMatrix dataset costs $335K/year. If it goes dark — or MacroMatrix raises prices — the Global Macro and European StatArb strategies are blind on GDP and inflation signals."*

---

**Step 6.** Right-click **Atlas Global Macro** (Strategy) → **Scene actions** → **Show PnL history**.

> PnL nodes expand with period labels (2022-FY through 2024-FY).
> Talking point: *"This strategy generated $78M net in 2024. The Nowcast dataset is a single point of failure with no identified substitute. That's the conversation procurement needs to have."*

---

**Step 7.** Use search phrase: **`Datasets with MNPI risk above 0.5`**

> Returns: Options Flow & Unusual Activity (0.7), Earnings Call NLP Sentiment (0.6), Dark Pool & Off-Exchange Flow (0.6) — all connected to live models.
> Talking point: *"Three datasets above the MNPI threshold are actively feeding live strategies. Compliance should know this."*

---

## Act 3 — "Should we renew these contracts?"

**Narrative:** Renewal season is coming. Let's see which contracts deserve a fight — and which ones we should let go.

---

**Step 8.** Clear the scene. Use search phrase: **`Renewals before 2025-03-31`**

> Returns: TransactIQ → Consumer Credit Card Spend US (Jan), OrbitalView → Industrial Activity Index (Mar).
> Talking point: *"Two contracts renewing in Q1. One has a 90-day notice period — that window may already be closed."*

---

**Step 9.** Double-click the **PROVIDES** edge between **TransactIQ** and **Consumer Credit Card Spend - US**.

> The property panel shows: `renewal_date`, `annual_fee_usd: $750K`, `auto_renew: true`, `notice_period_days: 90`.
> Talking point: *"This will auto-renew at $750K unless we act. It has a substitute — Parking Lot Occupancy — with 45% signal overlap and a $270K saving. Worth evaluating."*

---

**Step 10.** Right-click **Consumer Credit Card Spend - US** → Expand → **SUBSTITUTABLE_FOR**.

> Shows the substitution edge to Parking Lot Occupancy - US Retail with `overlap_score: 0.45` and `cost_delta_usd: $270K`.

---

**Step 11.** Use search phrase: **`Datasets costing more than 400000 USD`**

> Returns the top-cost datasets with their vendors.

Select all Dataset nodes (click one → right-click → **Select all nodes of this category**) → Expand → **SUBSTITUTABLE_FOR**.

> Only some datasets will grow a substitution edge — the others visually have none.
> Talking point: *"Five datasets above $400K/year. Three of them have no identified substitute. That's where negotiation leverage matters most."*

---

## Wrap-up talking points

| Question | Answer the graph gives |
|---|---|
| What does this dataset power? | Full path from dataset to PnL in one click |
| What breaks if it disappears? | Blast radius to live strategies |
| Are we paying for duplicate signals? | Correlated feature map across vendors |
| Which contracts are critical? | MNPI risk + no-substitute flag |
| What can we drop or renegotiate? | Substitution map + cost delta |

---

## Quick-access cheat sheet

| Action | How |
|---|---|
| Find any node | Type name in search bar (fulltext) |
| Full lineage | Right-click Dataset → Scene actions → Full path from dataset to PnL |
| Blast radius | Right-click Dataset → Scene actions → What breaks if I lose |
| Feature attribution | Right-click Model → Scene actions → Features driving |
| Redundancy check | Right-click Model → Scene actions → Show correlated features |
| Vendor exposure | Right-click DataVendor → Scene actions → Show full exposure |
| PnL history | Right-click Strategy → Scene actions → Show PnL history |
| Upcoming renewals | Search phrase: `Renewals before {date}` |
| Compliance audit | Search phrase: `Datasets with MNPI risk above {score}` |
| Underperformers | Search phrase: `Live models with Sharpe below {threshold}` |
| Cost filter | Search phrase: `Datasets costing more than {budget} USD` |
