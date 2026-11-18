<div align="center">

# ♥ Linux-Based Heart Rate Data Monitoring and Analysis System

**Engineering Linux — Continuous Assessment 01 · Group 6**

*Collect → Monitor → Analyze → Report → Backup — automated with Bash, Make and Python*

![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnubash&logoColor=white)
![Python](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?logo=linux&logoColor=black)
![Build](https://img.shields.io/badge/Build-GNU%20Make-blue)

</div>

---

## 📖 Overview

An end-to-end heart-rate monitoring pipeline built almost entirely from Linux
command-line tools. Readings are collected, validated, checked against clinical
thresholds in real time, analysed statistically and turned into a final report —
all with a single command: `make all`.

The sensor is **simulated**, so the project runs on any Linux machine or WSL.
Because `collect.sh` is the only script that touches the data source, it can be
replaced by a real sensor reader (e.g. Raspberry Pi + MAX30102) without changing
anything else.

## ✨ Features

- Modular pipeline: one Bash script per stage
- Central configuration (`config/project.conf`) — change thresholds without editing code
- Real-time colour-coded monitoring with CRITICAL / WARNING / NORMAL alerts
- Data cleaning and anomaly extraction with `sed`, `awk`, `sort`, `cut`
- Python statistics engine: mean, median, min, max, std-dev, resting HR, trend graph
- Professional final report with executive summary and recommendations
- Structured logging (`system.log`, `monitor.log`, `error.log`)
- Verified, rotated `tar.gz` backups
- Automated tests (`make test`) and strict-mode scripts with error trapping

## 🗂️ Project Structure

```
Engineering_Linux_Project/
├── README.md            ├── .gitignore        ├── .config (shared helpers)
├── requirements.txt     └── Makefile
├── config/project.conf  ← all thresholds and settings
├── scripts/             setup · collect · monitor · analyze · report · backup
├── python/              analysis.py · report.py
├── data/raw/            sensor_data.csv · sample_data.txt
├── data/processed/      cleaned_data.csv · filtered_data.txt
├── logs/                system.log · monitor.log · error.log
├── results/             summary.txt · alerts.txt · report.txt
├── tests/               test_data.csv
├── docs/                project_description · linux_commands · observations
└── backups/             timestamped archives
```

## 🚀 Quick Start

```bash
git clone <your-repo-url> Engineering_Linux_Project
cd Engineering_Linux_Project
make all          # setup → collect → monitor → analyze → report → backup
```

Run stages individually:

| Command        | What it does                                           |
|----------------|--------------------------------------------------------|
| `make setup`   | Checks tools, creates folders, sets permissions        |
| `make collect` | Generates simulated heart-rate readings                |
| `make monitor` | Classifies each reading, writes alerts and logs        |
| `make analyze` | Cleans data, extracts anomalies, computes statistics   |
| `make report`  | Builds `results/report.txt`                            |
| `make backup`  | Creates a verified compressed backup                   |
| `make test`    | Syntax checks + analysis check on known data           |
| `make clean`   | Removes generated data, logs and results               |

Custom number of samples: `bash scripts/collect.sh 300`
Reproducible data: `SEED=42 bash scripts/collect.sh`

## ⚙️ Configuration (`config/project.conf`)

| Setting | Default | Meaning |
|---|---|---|
| `SAMPLE_COUNT` | 120 | readings per run |
| `MIN_BPM` / `MAX_BPM` | 60 / 100 | normal range (outside = WARNING) |
| `CRITICAL_LOW` / `CRITICAL_HIGH` | 45 / 140 | critical limits |
| `VALID_MIN` / `VALID_MAX` | 20 / 250 | readings outside are dropped as sensor errors |
| `KEEP_BACKUPS` | 5 | archives retained |

## 🔄 How It Works

```
 collect.sh ──► monitor.sh ──► analyze.sh ──► report.sh ──► backup.sh
     │              │              │              │             │
 sensor_data   monitor.log     cleaned_data    report.txt   backups/*.tar.gz
    .csv       alerts.txt     filtered_data
                              summary.txt
```

## 🧪 Linux Concepts Demonstrated

Shell scripting (strict mode, functions, traps) · file permissions · I/O
redirection and pipes · `awk`/`sed`/`grep` text processing · process
substitution · logging · archiving with `tar` · build automation with `make`
· Git version control. See `docs/linux_commands.txt` for the full list.

## 👥 Team — Group 6

| SRN | Name |
|---|---|
| 01FE26BEC145 | Kushal M Angadi |
| 01FE26BEC149 | Gagan Joshi |
| 01FE26BEC415 | Nandeesh Tirlapur |
| 01FE26BEC150 | Pratham Shetty |

## 🔮 Future Work

Real sensor input (Raspberry Pi + MAX30102) · cron scheduling · e-mail alerts ·
charts · heart-rate-variability analysis · web dashboard.
