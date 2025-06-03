#!/bin/bash

# Directory containing the PBS scripts to submit
SCRIPT_DIR="/job_scripts/DAGGNN/non_linear"

# Move to the directory
cd "$SCRIPT_DIR" || { echo "Directory not found: $SCRIPT_DIR"; exit 1; }

# Submit all matching PBS job array scripts
for script in NL_N*_array.sh; do
  if [[ -f "$script" ]]; then
    echo "Submitting: $script"
    qsub "$script"
  fi
done
