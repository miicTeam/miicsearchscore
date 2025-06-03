#!/bin/bash

SCRIPT_DIR="job_scripts/miic/continuous/linear_gaussian"
LOG_FILE="submitted_jobs.log"
DATE_NOW=$(date +"%Y-%m-%d %H:%M:%S")

echo "== Job submission started: $DATE_NOW ==" >> "$LOG_FILE"

for script in "$SCRIPT_DIR"/*.sh; do
  if [[ -f "$script" ]]; then
    echo "Submitting $script..."
    JOB_ID=$(qsub "$script")
    echo "[$(date +"%H:%M:%S")] $script => Job ID: $JOB_ID" >> "$LOG_FILE"
  fi
done

echo "== Job submission completed ==" >> "$LOG_FILE"