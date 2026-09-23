# Kiribati Budget Transparency — powered by Virtual Economics

A native iOS app (SwiftUI, iOS 17+) for Kiribati's recurrent budget: what each budget
appropriated, what supplementary Acts added, what the Annual Account says was spent,
how it splits across ministries, and who funds the development budget. Every figure
carries its source, and every place the documents disagree is shown rather than hidden.

Sister app to **PNG Budget Transparency** (`../PNGBudgetTransparency`), same design.

## What's in the app

| Tab | What it shows |
|---|---|
| **Overview** | Total operating budget (appropriation + statutory), revised budget and actual expenditure, 2011–2026; Development Fund share of the appropriation; year-by-year list back to 1994 supplementaries. Tap a year for its components, supplementaries, outturn and reconciliation chain. |
| **Ministries** | Operating budget by ministry from Table 2 of each recurrent budget volume, 2009 and 2011–2025 (27 heads, matched across renames and renumbering), with page citations and the appropriation/statutory split. |
| **Donors** | 2026 Development Budget by donor (Table 3): 2025 budget, revised, warrant, 2026 budget and 2027–29 estimates. |
| **Integrity** | Whether budget + supplementaries = the Annual Account's revised budget, year by year; the two conflicting supplementary series (workbook tension T45); ministry lines checked against every printed Grand Total; years not charted and why. |
| **About** | Method, authorities, coverage limits, dataset version. |

### Show figures as…

One app-wide control switches every figure between:

| View | Calculation |
|---|---|
| **A$** | As printed (whole Australian dollars). |
| **2025 prices** | ÷ KNSO all-items CPI, annual average of the monthly index, 2025 = 100 (2025 = Jan–Sep). No index exists for 2026. |
| **% GDP** | ÷ nominal GDP — KNSO national accounts (Table 1) to 2021, IMF Country Report 26/099 from 2022 (chained, not reconciled). |
| **% spending** | ÷ IMF total central-government expenditure (recurrent + development, incl. donor projects). |

## Build and run

Xcode 16 or later. Open `KiribatiBudgetTransparency.xcodeproj`, choose an iPhone simulator,
⌘R. For a device, set your Team (bundle id `com.virtualeconomics.kiribatibudget`).

## Refreshing the data

```sh
pip install openpyxl
python3 tools/build_kiribati_data.py --src <folder of Kiribati Data Store exports>
```

The script lists the files it needs. It checks every ministry table against its printed
Grand Total and prints any gap:

* 2009, 2011–2022, 2024, 2025 — lines match the printed total to within A$4.
* 2023 and 2026 — no Table 2 extracted; their head tables book the Development Fund,
  subsidies and debt service inside ministries, so they are reported but not charted.

## Data provenance

* **Original budget** — recurrent budget volume Table 2, cross-checked against the enacted
  Appropriation Act where one survives.
* **Supplementary** — Supplementary Appropriation Acts (PacLII, parliament.gov.ki) and
  supplementary volumes. Service year, not title year, is the key.
* **Outturn** — the Annual Account (none usable for 2019).
* **Denominators** — KNSO CPI (to Sep 2024; Pacific Data Hub DF_CPI after), KNSO GDP master
  table 2024, IMF CR 26/099 central government operations.

Status: **beta, not an official record, not audited.**
