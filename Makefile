# =============================================================
#  Makefile — one command per pipeline stage
#  (uses ">" as recipe prefix, so no TAB characters are needed)
# =============================================================
.RECIPEPREFIX = >
SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL:

.PHONY: help setup collect monitor analyze report backup all test clean distclean

help:
> @bash -c 'source config/project.conf; ROOT_DIR=$$PWD; source .config; banner'
> @echo "  Usage: make <target>"
> @echo ""
> @echo "    setup      Check tools, create folders, set permissions"
> @echo "    collect    Generate simulated heart-rate sensor data"
> @echo "    monitor    Check readings against thresholds, write alerts"
> @echo "    analyze    Clean data and compute statistics"
> @echo "    report     Build the final report"
> @echo "    backup     Create a verified tar.gz backup"
> @echo "    all        Run the complete pipeline (setup -> backup)"
> @echo "    test       Syntax checks + unit check on tests/test_data.csv"
> @echo "    clean      Remove generated data, logs and results"
> @echo "    distclean  clean + remove all backups"
> @echo ""

setup:
> @bash scripts/setup.sh

collect:
> @bash scripts/collect.sh

monitor:
> @bash scripts/monitor.sh

analyze:
> @bash scripts/analyze.sh

report:
> @bash scripts/report.sh

backup:
> @bash scripts/backup.sh

all: setup collect monitor analyze report backup
> @echo ""
> @echo "  ✔ Full pipeline completed — see results/report.txt"

test:
> @echo "Running tests ..."
> @for f in scripts/*.sh .config; do bash -n "$$f" && echo "  ✔ shell syntax OK   $$f"; done
> @python3 -m py_compile python/analysis.py python/report.py && echo "  ✔ python syntax OK  python/*.py"
> @python3 python/analysis.py --input tests/test_data.csv --output /tmp/hr_test_summary.txt --quiet
> @grep -q "Samples *: 10"  /tmp/hr_test_summary.txt && echo "  ✔ sample count correct (10)"
> @grep -q "Maximum *: 130" /tmp/hr_test_summary.txt && echo "  ✔ maximum BPM correct (130)"
> @grep -q "Minimum *: 48"  /tmp/hr_test_summary.txt && echo "  ✔ minimum BPM correct (48)"
> @grep -q "Mean *: 74.9"   /tmp/hr_test_summary.txt && echo "  ✔ mean BPM correct (74.9)"
> @grep -q "WARNING  *:    2" /tmp/hr_test_summary.txt && echo "  ✔ warning count correct (2)"
> @echo "All tests passed."

clean:
> @rm -f data/raw/* data/processed/* results/* logs/*.log
> @rm -rf python/__pycache__
> @echo "  ✔ Generated files removed (run 'make setup' to recreate logs)"

distclean: clean
> @rm -f backups/*.tar.gz
> @echo "  ✔ Backups removed"
