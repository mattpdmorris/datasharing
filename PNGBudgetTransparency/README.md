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
| **Overview** | Budgeted vs outturn, 2005–2026, for expenditure, revenue and the budget balance. Switch between printed kina, real 2025 kina (CPI-deflated) and % of GDP. Tap a year for the full provenance trail. |
| **Agencies** | 195 national agencies across nine Volume 2A editions (2018–2026): appropriation by sector, searchable agency list, each agency's appropriation vs actual, and every printing of every figure with its volume and page. |
| **Projects** | Public Investment Programme projects (shown only when `pip_projects.json` is bundled). |
| **Integrity** | Every place two official documents disagree: restated years, outturns revised after the Final Budget Outcome, budget-vs-FBO reprint differences, duplicate agency lines and misprinted names. |
| **About** | Method, which document is the authority for what, coverage limits, dataset version and document list. |

Every figure carries its source: document, page, table and column. Transformations
(real terms, % of GDP) are labelled as such; years with no official denominator
drop out rather than being estimated.

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
    --pip  ../png-budget-site/png/budget/data/pip_projects.parquet   # optional; needs pyarrow
```

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
* **Prices** — Bank of PNG Quarterly Economic Bulletin Table 10.1 (headline CPI,
  2025 = 100; chain-linked across the 2012 basket change).
* **GDP** — BPNG QEB Table 10.8 (1977–2006) and PNG Treasury final vintages (2015–2024).

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
  Resources/Data/  bundled budget_payload.json (+ optional pip_projects.json)
  Assets.xcassets  app icon and brand colours
tools/build_app_data.py   regenerates Resources/Data from the site build
```
