# Global Fund Explorer (iOS)

A SwiftUI app for browsing Global Fund grant data from the public
[Global Fund Data Service](https://data-service.theglobalfund.org) OData API.

## What it does

| Tab | Screens |
| --- | --- |
| **Countries** | Portfolio totals, searchable country and area list, pinned countries (swipe a row to pin it), pull to refresh |
| Country detail | Signed, disbursed, grant and active-grant totals, a chart of signed vs disbursed by component, grants grouped by disease with an "active only" filter |
| Grant detail | Principal recipient, status, cycle, programme dates, signed, committed and disbursed amounts, disbursement chart (each payment plus the running total), payment list |
| Country "More data" | Allocations by cycle, budget by cost category, expenditure by module, annual results, eligibility, funding requests, and documents (opened in Safari) |
| **Grants** | Search every grant by number, country, recipient or component, filtered by component and active status |
| **Donors** | Pledges vs contributions per replenishment period, and every donor's pledged and paid amounts, filterable by period |
| **Results** | Annual results across all countries by year and component, with a trend chart for each indicator |
| **About** | Data source and disclaimer, refresh and clear-cache controls, an editable API base URL |

Grant data is cached on the device and refreshed at most once a day. Pull to
refresh or tap **Refresh now** to force it. Disbursements and the other datasets
are fetched when you open their screen.

## Build and run

Requirements: macOS with **Xcode 15 or later**, targeting **iOS 17 or later**.

```sh
brew install xcodegen
cd ios
xcodegen generate
open GlobalFundExplorer.xcodeproj
```

Run `xcodegen generate` again whenever files are added or removed, so the Xcode
project picks them up.

In Xcode, select the `GlobalFundExplorer` target, set your team under
**Signing & Capabilities**, change the bundle ID from `org.example.GlobalFundExplorer`,
then run on a simulator or device. Press **⌘U** to run the tests.

**Without XcodeGen:** create a new iOS App project in Xcode (SwiftUI, Swift),
delete its generated `ContentView.swift` and `<Name>App.swift`, and drag the
`GlobalFundExplorer/` folder into the project. Do the same with
`GlobalFundExplorerTests/` into a Unit Testing Bundle target.

## API version and names

The app uses **version 4.2** of the Data Service API
(`https://fetch.theglobalfund.org/v4.2/odata/`), the same one the Global Fund's
own [Data Explorer](https://github.com/globalfund/data-explorer-server) uses.
Older versions such as v3.3 are retired and return HTTP 403.

- Grants come from `Grants`, with `status`, `geography`, `activityArea` and
  `principalRecipient` expanded.
- Disbursements come from `allFinancialIndicators`, filtered to
  `indicatorName eq 'Disbursement Amount - Reference Rate'` and the grant's code.
- Allocations, budgets, expenditure, and pledges and contributions also come from
  `allFinancialIndicators`, told apart by `financialDataSet` and `indicatorName`.
  Results come from `allProgrammaticIndicators`, and eligibility, funding
  requests and documents from `Eligibility`, `FundingRequests` and `Documents`.
  These queries are in `GlobalFundAPI+Datasets.swift` and use OData `$apply`
  so the server does the totalling.

Every name is in `GlobalFundExplorer/API/APIConfig.swift`. Each value has a list
of candidate JSON keys; the first match wins, case-insensitively, and a dotted
key such as `geography.name` reads from an expanded record.

If the Global Fund releases a new version, try it with a URL such as
`https://fetch.theglobalfund.org/v4.2/odata/Grants?$top=1` in a browser, then
update `APIConfig`. You can also change the base URL in the app's **About** tab
without rebuilding. **HTTP 403 or 404** usually means the version or an entity
set name has changed.

## Structure

```
GlobalFundExplorer/
  App/          App entry point and tab layout
  API/          APIConfig (all API names), OData client with paging, tolerant JSON mapping
  Models/       Grant, Disbursement, CountrySummary, Disease
  Store/        GrantStore (observable app state, pins) and DiskCache (offline copy)
  Views/        Country list and detail, grant detail and search, settings
  Support/      Formatting helpers and preview-only sample data
GlobalFundExplorerTests/
  Field mapping, date parsing, grouping, and API paging and filtering against a mock URL protocol
```

## How to read the data

- Amounts are in **US dollars at the Global Fund reference rate**.
- **Signed** is the amount in the grant agreement. **Committed** is what the
  Global Fund has formally set aside. **Disbursed** is what has actually been
  paid. Keep these labels distinct.
- Multi-country grants appear under their multi-country "area" name, not a
  single country.

## Before releasing

- Read the Data Service terms of use and follow its licence and attribution
  requirements. The About screen already credits the source and says the app
  isn't endorsed by the Global Fund.
- Add an app icon (an `Assets.xcassets` with an `AppIcon` set).
- Apple rejects apps that only wrap a website. The offline cache, charts and
  pins count as value the app adds; alerts for new disbursements on pinned
  countries would be a natural next feature.
