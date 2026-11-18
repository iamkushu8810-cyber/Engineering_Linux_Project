#!/usr/bin/env python3
"""
analysis.py — Heart-rate statistics engine (Python standard library only).

Reads the cleaned CSV (timestamp,sample_id,bpm), computes descriptive
statistics, classifies every reading and writes results/summary.txt.

Usage:
    python3 python/analysis.py [--input FILE] [--output FILE] [--quiet]
"""
from __future__ import annotations

import argparse
import csv
import os
import statistics
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BLOCKS = "▁▂▃▄▅▆▇█"
LINE = "=" * 64
THIN = "-" * 64


# --------------------------------------------------------------- config
def _int(name: str, default: int) -> int:
    try:
        return int(float(os.environ.get(name, default)))
    except ValueError:
        return default


def rel(path) -> str:
    """Path relative to the project root, for tidy output."""
    try:
        return str(Path(path).resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def load_config() -> dict:
    """Thresholds come from config/project.conf (exported by the shell)."""
    return {
        "project": os.environ.get(
            "PROJECT_NAME", "Linux-Based Heart Rate Data Monitoring and Analysis System"
        ),
        "version": os.environ.get("PROJECT_VERSION", "1.0.0"),
        "patient": os.environ.get("PATIENT_ID", "P-001"),
        "min_bpm": _int("MIN_BPM", 60),
        "max_bpm": _int("MAX_BPM", 100),
        "crit_low": _int("CRITICAL_LOW", 45),
        "crit_high": _int("CRITICAL_HIGH", 140),
    }


# ----------------------------------------------------------------- data
def classify(bpm: int, cfg: dict) -> str:
    if bpm <= cfg["crit_low"] or bpm >= cfg["crit_high"]:
        return "CRITICAL"
    if bpm < cfg["min_bpm"] or bpm > cfg["max_bpm"]:
        return "WARNING"
    return "NORMAL"


def load_readings(path: Path) -> list[dict]:
    readings = []
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            try:
                readings.append(
                    {
                        "timestamp": row["timestamp"].strip(),
                        "sample_id": row["sample_id"].strip(),
                        "bpm": int(row["bpm"]),
                    }
                )
            except (KeyError, ValueError, AttributeError):
                continue  # skip malformed rows
    return readings


def _parse_ts(value: str):
    try:
        return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def fmt_duration(seconds: float) -> str:
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    return f"{h}h {m:02d}m {s:02d}s" if h else f"{m}m {s:02d}s"


def sparkline(values: list[float], width: int = 60) -> str:
    """Compress the BPM series into a one-line unicode trend graph."""
    if not values:
        return ""
    n = len(values)
    if n > width:
        size = n / width
        values = [
            statistics.mean(values[int(i * size): max(int((i + 1) * size), int(i * size) + 1)])
            for i in range(width)
        ]
    lo, hi = min(values), max(values)
    if hi == lo:
        return BLOCKS[3] * len(values)
    return "".join(BLOCKS[int((v - lo) / (hi - lo) * (len(BLOCKS) - 1))] for v in values)


def compute_stats(readings: list[dict], cfg: dict) -> dict:
    if not readings:
        raise ValueError("no valid readings to analyse")
    bpms = [r["bpm"] for r in readings]
    n = len(bpms)
    ordered = sorted(bpms)
    statuses = [classify(b, cfg) for b in bpms]
    counts = {s: statuses.count(s) for s in ("NORMAL", "WARNING", "CRITICAL")}

    longest = current = 0
    for s in statuses:
        current = current + 1 if s != "NORMAL" else 0
        longest = max(longest, current)

    t0, t1 = _parse_ts(readings[0]["timestamp"]), _parse_ts(readings[-1]["timestamp"])
    duration = (t1 - t0).total_seconds() if t0 and t1 else 0

    return {
        "n": n,
        "bpms": bpms,
        "mean": statistics.mean(bpms),
        "median": statistics.median(bpms),
        "stdev": statistics.stdev(bpms) if n > 1 else 0.0,
        "min": ordered[0],
        "max": ordered[-1],
        "resting": ordered[int(0.10 * (n - 1))],  # 10th percentile ≈ resting rate
        "counts": counts,
        "pct": {k: 100.0 * v / n for k, v in counts.items()},
        "longest_streak": longest,
        "first": readings[0]["timestamp"],
        "last": readings[-1]["timestamp"],
        "duration": duration,
        "low": sum(1 for b in bpms if b < cfg["min_bpm"]),
        "high": sum(1 for b in bpms if b > cfg["max_bpm"]),
    }


def assessment(st: dict) -> tuple[str, str]:
    if st["counts"]["CRITICAL"] > 0:
        return "ATTENTION", "Critical readings detected — review alerts and verify the sensor."
    if st["pct"]["WARNING"] >= 10:
        return "CAUTION", "Frequent out-of-range readings — continue monitoring closely."
    return "STABLE", "Heart rate stayed within the expected range."


def bar(count: int, total: int, width: int = 30) -> str:
    return "█" * round(width * count / total) if total else ""


# -------------------------------------------------------------- render
def render_summary(st: dict, cfg: dict, source: str) -> str:
    verdict, note = assessment(st)
    n = st["n"]
    mid = n - st["low"] - st["high"]
    L = [
        LINE,
        " HEART RATE ANALYSIS SUMMARY",
        LINE,
        f" Project    : {cfg['project']}",
        f" Version    : {cfg['version']}",
        f" Generated  : {datetime.now():%Y-%m-%d %H:%M:%S}",
        f" Source     : {source}",
        THIN,
        " DATASET",
        f"   {'Samples':<16}: {n}",
        f"   {'Period':<16}: {st['first']}  ->  {st['last']}",
        f"   {'Duration':<16}: {fmt_duration(st['duration'])}",
        "",
        " STATISTICS (BPM)",
        f"   {'Mean':<16}: {st['mean']:.1f} BPM",
        f"   {'Median':<16}: {st['median']:.1f} BPM",
        f"   {'Minimum':<16}: {st['min']} BPM",
        f"   {'Maximum':<16}: {st['max']} BPM",
        f"   {'Std deviation':<16}: {st['stdev']:.2f}",
        f"   {'Resting (est.)':<16}: {st['resting']} BPM  (10th percentile)",
        "",
        f" CLASSIFICATION  (normal {cfg['min_bpm']}-{cfg['max_bpm']} | critical <={cfg['crit_low']} or >={cfg['crit_high']})",
        f"   {'NORMAL':<9}: {st['counts']['NORMAL']:>4}  {st['pct']['NORMAL']:5.1f}%  {bar(st['counts']['NORMAL'], n)}",
        f"   {'WARNING':<9}: {st['counts']['WARNING']:>4}  {st['pct']['WARNING']:5.1f}%  {bar(st['counts']['WARNING'], n)}",
        f"   {'CRITICAL':<9}: {st['counts']['CRITICAL']:>4}  {st['pct']['CRITICAL']:5.1f}%  {bar(st['counts']['CRITICAL'], n)}",
        "",
        " DISTRIBUTION BY ZONE",
        f"   {'Below normal':<14}: {st['low']:>4}  {bar(st['low'], n)}",
        f"   {'Normal range':<14}: {mid:>4}  {bar(mid, n)}",
        f"   {'Above normal':<14}: {st['high']:>4}  {bar(st['high'], n)}",
        f"   Longest abnormal streak: {st['longest_streak']} reading(s)",
        "",
        " TREND",
        f"   {sparkline(st['bpms'])}",
        f"   (low = {st['min']} BPM   high = {st['max']} BPM)",
        THIN,
        f"   {'Assessment':<16}: {verdict}",
        f"   {note}",
        LINE,
        "",
    ]
    return "\n".join(L)


# ---------------------------------------------------------------- main
def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Heart-rate statistics engine")
    ap.add_argument("--input", default=os.environ.get("CLEAN_FILE", ROOT / "data/processed/cleaned_data.csv"))
    ap.add_argument("--output", default=os.environ.get("SUMMARY_FILE", ROOT / "results/summary.txt"))
    ap.add_argument("--quiet", action="store_true", help="do not print the summary")
    args = ap.parse_args(argv)

    cfg = load_config()
    try:
        readings = load_readings(Path(args.input))
        stats = compute_stats(readings, cfg)
    except FileNotFoundError:
        print(f"ERROR: input file not found: {args.input}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    text = render_summary(stats, cfg, rel(args.input))
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    if not args.quiet:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
