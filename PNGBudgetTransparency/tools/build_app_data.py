#!/usr/bin/env python3
"""Refresh the data bundled into the PNG Budget Transparency iOS app.

The app reads the same payload the Virtual Economics data site publishes at
/png/budget/ (the <script id="payload"> blob), so the site and the app can never
disagree about a figure. Optionally it also bundles the Public Investment
Programme projects from the site's pip_projects.parquet export.

Usage
  python3 tools/build_app_data.py --site path/to/png-budget-site/png/budget/index.html \
      [--pip path/to/png-budget-site/png/budget/data/pip_projects.parquet]

  # or, if you already have the payload as JSON:
  python3 tools/build_app_data.py --payload budget_payload.json

Writes into PNGBudgetTransparency/Resources/Data/:
  budget_payload.json   minified site payload (required by the app)
  pip_projects.json     compact PIP table (optional; the Projects tab hides without it)
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "PNGBudgetTransparency" / "Resources" / "Data"

REQUIRED_KEYS = {"generated", "corpus_version", "measures", "fiscal", "agencies",
                 "series_codes", "volumes", "facts", "counts"}


def payload_from_site(index_html: Path) -> dict:
    text = index_html.read_text(encoding="utf-8")
    m = re.search(r'<script id="payload" type="application/json">(.*?)</script>', text, re.S)
    if not m:
        sys.exit(f"{index_html}: no <script id=\"payload\"> block found")
    raw = m.group(1).strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return json.loads(html.unescape(raw))


def check_payload(p: dict) -> None:
    missing = REQUIRED_KEYS - p.keys()
    if missing:
        sys.exit(f"payload is missing keys the app needs: {sorted(missing)}")
    n_ag = len(p["agencies"])
    for i, f in enumerate(p["facts"]):
        if len(f) != 8:
            sys.exit(f"facts[{i}] has {len(f)} fields, expected 8 "
                     "[agencyIdx, edition, refYear, serIdx, value, printedPage, pdfPage, volIdx]")
        if not (0 <= f[0] < n_ag and 0 <= f[3] < len(p["series_codes"]) and 0 <= f[7] < len(p["volumes"])):
            sys.exit(f"facts[{i}] points outside agencies/series_codes/volumes: {f}")


def pip_table(parquet: Path) -> dict:
    """Compact the PIP export into the shape PIPData.swift decodes.

    projects: one per PIP number, named as its most recent edition names it
    facts:    [projectIdx, edition, refYear, value K m, printedPage, pdfPage, volumeIdx]
              refYear 0 marks the five-year total as the volume prints it
    """
    try:
        import pyarrow.parquet as pq
    except ImportError:
        sys.exit("pip install pyarrow to convert the PIP parquet export")
    rows = pq.read_table(parquet).to_pylist()
    need = {"budget_edition", "executing_agency_code", "executing_agency_name", "programme_group",
            "pip_number", "project_name", "ref_year", "value_kina_m", "source_volume",
            "printed_page", "pdf_page"}
    missing = need - set(rows[0]) if rows else need
    if missing:
        sys.exit(f"{parquet}: missing columns {sorted(missing)}")

    latest: dict[str, dict] = {}
    for r in rows:
        k = r["pip_number"]
        if k not in latest or r["budget_edition"] >= latest[k]["budget_edition"]:
            latest[k] = r
    numbers = sorted(latest)
    pidx = {n: i for i, n in enumerate(numbers)}
    volumes = sorted({r["source_volume"] for r in rows})
    vidx = {v: i for i, v in enumerate(volumes)}
    projects = [{
        "pip": n,
        "name": latest[n]["project_name"].strip(),
        "agency_code": latest[n]["executing_agency_code"],
        "agency": latest[n]["executing_agency_name"].strip(),
        "group": latest[n]["programme_group"],
        "names": sorted({r["project_name"].strip() for r in rows if r["pip_number"] == n} - {latest[n]["project_name"].strip()}),
    } for n in numbers]
    facts = [[pidx[r["pip_number"]], r["budget_edition"], (0 if r["ref_year"] == "5yr_total" else int(r["ref_year"])), round(r["value_kina_m"], 3),
              r["printed_page"], r["pdf_page"], vidx[r["source_volume"]]] for r in rows]
    facts.sort(key=lambda f: (f[0], f[1], f[2]))
    return {"volumes": volumes, "projects": projects, "facts": facts}


def write_json(obj, path: Path) -> None:
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {path.relative_to(HERE.parent)}  ({path.stat().st_size / 1024:,.0f} KB)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--site", type=Path, help="the site's png/budget/index.html")
    src.add_argument("--payload", type=Path, help="payload JSON already extracted")
    ap.add_argument("--pip", type=Path, help="pip_projects.parquet from the site's data/ folder")
    a = ap.parse_args()

    payload = payload_from_site(a.site) if a.site else json.loads(a.payload.read_text(encoding="utf-8"))
    check_payload(payload)
    OUT.mkdir(parents=True, exist_ok=True)
    write_json(payload, OUT / "budget_payload.json")
    print(f"  generated {payload['generated']}, corpus {payload['corpus_version']}, "
          f"{len(payload['fiscal'])} fiscal records, {len(payload['agencies'])} agencies, "
          f"{len(payload['facts'])} agency facts")

    if a.pip:
        write_json(pip_table(a.pip), OUT / "pip_projects.json")


if __name__ == "__main__":
    main()
