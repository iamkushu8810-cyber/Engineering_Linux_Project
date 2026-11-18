#!/usr/bin/env python3
"""
report.py — builds the final, presentation-ready report (results/report.txt)
from the cleaned data and the alerts raised by monitor.sh.

Usage:
    python3 python/report.py [--input FILE] [--alerts FILE] [--output FILE] [--quiet]
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

import analysis as A  # same folder: python/analysis.py

ROOT = A.ROOT
LINE, THIN = A.LINE, A.THIN


def read_alerts(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [ln.rstrip() for ln in path.read_text(encoding="utf-8").splitlines()
            if ln.startswith("[")]


def recommendations(st: dict) -> list[str]:
    recs = []
    if st["counts"]["CRITICAL"]:
        recs.append("Investigate every CRITICAL alert; confirm whether it is a real event or sensor noise.")
    if st["pct"]["WARNING"] >= 10:
        recs.append("Warnings exceed 10% of readings — consider a longer monitoring window.")
    if st["longest_streak"] >= 3:
        recs.append(f"A streak of {st['longest_streak']} consecutive abnormal readings was seen — check the sensor contact.")
    if st["stdev"] > 12:
        recs.append("High variability (std dev > 12) — verify sampling quality.")
    if not recs:
        recs.append("No action required. Keep the current monitoring schedule.")
    return recs


def build_report(st: dict, cfg: dict, alerts: list[str], source: str) -> str:
    verdict, note = A.assessment(st)
    n = st["n"]
    L = [
        LINE,
        f" {cfg['project'].upper()}",
        " FINAL MONITORING REPORT",
        LINE,
        f" Patient / Subject : {cfg['patient']}",
        f" Report generated  : {datetime.now():%Y-%m-%d %H:%M:%S}",
        f" Data source       : {source}",
        f" Observation window: {st['first']}  ->  {st['last']}  ({A.fmt_duration(st['duration'])})",
        THIN,
        " 1. EXECUTIVE SUMMARY",
        f"    Overall status : {verdict}",
        f"    {note}",
        f"    {n} readings analysed: {st['counts']['NORMAL']} normal, "
        f"{st['counts']['WARNING']} warning, {st['counts']['CRITICAL']} critical.",
        "",
        " 2. KEY METRICS",
        f"    Average heart rate : {st['mean']:.1f} BPM",
        f"    Median             : {st['median']:.1f} BPM",
        f"    Range              : {st['min']} - {st['max']} BPM",
        f"    Resting (est.)     : {st['resting']} BPM",
        f"    Std deviation      : {st['stdev']:.2f}",
        "",
        " 3. THRESHOLDS USED",
        f"    Normal   : {cfg['min_bpm']} - {cfg['max_bpm']} BPM",
        f"    Critical : <= {cfg['crit_low']} or >= {cfg['crit_high']} BPM",
        "",
        " 4. HEART-RATE TREND",
        f"    {A.sparkline(st['bpms'])}",
        "",
        f" 5. ALERT LOG ({len(alerts)} total, latest 10 shown)",
    ]
    L += [f"    {a}" for a in alerts[-10:]] or ["    None — no abnormal readings."]
    L += ["", " 6. RECOMMENDATIONS"]
    L += [f"    - {r}" for r in recommendations(st)]
    L += [
        "",
        " 7. GENERATED ARTEFACTS",
        "    data/raw/sensor_data.csv          raw sensor readings",
        "    data/processed/cleaned_data.csv   validated readings",
        "    data/processed/filtered_data.txt  abnormal readings only",
        "    results/summary.txt               statistical summary",
        "    results/alerts.txt                alert list",
        "    logs/monitor.log                  per-reading monitor log",
        LINE,
        "",
    ]
    return "\n".join(L)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Final report generator")
    ap.add_argument("--input", default=os.environ.get("CLEAN_FILE", ROOT / "data/processed/cleaned_data.csv"))
    ap.add_argument("--alerts", default=os.environ.get("ALERTS_FILE", ROOT / "results/alerts.txt"))
    ap.add_argument("--output", default=os.environ.get("REPORT_FILE", ROOT / "results/report.txt"))
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    cfg = A.load_config()
    try:
        st = A.compute_stats(A.load_readings(Path(args.input)), cfg)
    except FileNotFoundError:
        print(f"ERROR: input file not found: {args.input}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    text = build_report(st, cfg, read_alerts(Path(args.alerts)), A.rel(args.input))
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    if not args.quiet:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
