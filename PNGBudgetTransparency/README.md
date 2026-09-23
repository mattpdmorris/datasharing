# PNG Budget Transparency — powered by Virtual Economics

A native iOS app (SwiftUI, iOS 17+) that puts Papua New Guinea's national budget
record in people's pockets: what each budget said, what Treasury later reported,
where every figure came from, and where official documents disagree.

It reads the same data payload the Virtual Economics data site publishes for
**Papua New Guinea — Budget Record**, so the app and the site can never
disagree about a number.

## What's in the app

| Tab | What it shows |
|---|---|
| **Overview** | Budgeted vs outturn, 2005–2026, for expenditure, revenue and the budget balance. Tap a year for the full provenance trail. |
| **Agencies** | 195 national agencies across nine Volume 2A editions (2018–2026): appropriation by sector, searchable agency list, each agency's appropriation vs actual, and every printing of every figure with its volume and page. |
| **Projects** | Public Investment Programme projects (shown only when `pip_projects.json` is bundled). |
| **Integrity** | Every place two official documents disagree: restated years, outturns revised after the Final Budget Outcome, budget-vs-FBO reprint differences, duplicate agency lines and misprinted names. |
| **About** | Method, which document is the authority for what, coverage limits, dataset version and document list. |

Every figure carries its source: document, page, table and column.

### Show figures as…

One app-wide control (on every tab) switches all figures between:

| View | How it is calculated (ANU PNG National Budget Database) |
|---|---|
| **Kina** | As printed in the source documents. |
| **Constant 2025 prices** | ÷ price index, 2025 = 100. Default: CPI chained from Table 9 annual-average inflation. Alternative: the GDP deflator from the Analysis sheet (ANU's own real series use it; in PNG it swings with LNG prices). |
| **% of GDP** | ÷ nominal GDP (Analysis sheet, new NSO series; 2005–06 from the ANU PNG Economic Database so old and new GDP series are never mixed). |
| **% of total spending** | ÷ total general government expenditure and net lending for that year (actual to 2024, 2025 estimate, 2026+ projections). |

Transformations are labelled; a year without the denominator drops out rather than
being estimated; figures using an estimated or projected denominator are marked "e".
The Integrity tab always stays in printed kina, because it compares printed numbers.

## Build and run

Requirements: **Xcode 16 or later** (the project uses Xcode 16 synchronised folders,
so any file added under `PNGBudgetTransparency/` is picked up automatically).

1. Open `PNGBudgetTransparency.xcodeproj`.
2. Select the **PNGBudgetTransparency** scheme and an iPhone simulator.
3. ⌘R.

To run on a device or ship to TestFlight, set your **Team** under
*Signing & Capabilities* (bundle id `com.virtualeconomics.pngbudget` — change it if
that id is not registered to your Apple developer account).

## Refreshing the data

The bundled data lives in `PNGBudgetTransparency/Resources/Data/`. It is produced from
the data site build (`png-budget-site/`) by one script:

```sh
python3 tools/build_app_data.py \
    --site ../png-budget-site/png/budget/index.html \
    --pip  ../png-budget-site/png/budget/data/pip_projects.parquet \
    --anu-budget "2025-12 — PNG National Budget Database — 2026 Budget.xlsx" \
    --anu-econ   "2026-08-12 — PNG Economic Database — Dashboard1 crosstab (Maindatabase30June).csv"
# needs: pip install pyarrow openpyxl
```

When the ANU publishes a new edition of the budget database, point `--anu-budget` at it
and rebuild; the script reads rows by label and aligns them by year column.

The script extracts the site's `<script id="payload">` blob, validates it, and writes
`budget_payload.json` (and `pip_projects.json` if `--pip` is given). Rebuild the app
afterwards.

**Over-the-air updates.** On launch the app also tries
`https://data.virtualeconomics.com/png/budget/payload.json`
(`DataStore.remotePayloadURL`). If that file exists, decodes cleanly and has a newer
`generated` date than the bundled copy, the app uses it. Publishing the same
`budget_payload.json` at that path on the data site is therefore all that is needed to
update every installed copy without an App Store release. Until then the app simply
uses the bundled data.

## Data provenance

* **Budgeted figures** — each year's Budget Volume 1, Budget Balance table.
* **Outturn** — that year's Final Budget Outcome; where none is held, the "Actual"
  column of a later Budget Volume 1, marked as such in the app.
* **Agency lines** — Budget Volume 2A, editions 2018–2026.
* **Prices, GDP and total spending** — ANU Development Policy Centre / UPNG
  *PNG National Budget Database*, 2026 Budget edition (updated 11 Dec 2025, David Poka and
  Rubayat Chowdhury), plus the ANU *PNG Economic Database* for 2005–06 GDP.

Status: **beta, not an official record, not audited.** Source data remains subject to
the terms of the publishing agency; the extraction, annotations and analysis are offered
for reuse with attribution to Virtual Economics.

## Project layout

```
PNGBudgetTransparency.xcodeproj
PNGBudgetTransparency/
  App/          app entry point and tab shell
  Models/       Payload.swift (site payload, Codable) and Domain.swift (derived types)
  Data/         DataStore (loading, remote refresh, queries) and number formatting
  Views/        Overview, YearDetail, Agencies, Projects, Integrity, About
  Components/   brand mark, stat tiles, source citations, flag badges
  Resources/Data/  bundled budget_payload.json, pip_projects.json, anu_denominators.json
  Assets.xcassets  app icon and brand colours
tools/build_app_data.py   regenerates Resources/Data from the site build
```
