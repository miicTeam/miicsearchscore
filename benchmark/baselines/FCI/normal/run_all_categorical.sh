#!/bin/bash

# ==============================================================================
# File        : run_all_categorical.sh
# Description : Runs FCI across all settings for simulated
#               categorical data (models ∈ {Alarm, Insurance, Barley, Mildew},
#               sample_sizes ∈ {100,...,20000},  rep_idx ∈ 1:50).
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - Python environment with FCI
#   - simulated data under simulated_data/categorical/normal/
#
# License     : GPL (>= 3)
# ==============================================================================

MODELS=("Alarm" "Insurance" "Barley" "Mildew")
REPLICATES=$(seq 1 50)
SAMPLE_SIZES="100,250,500,1000,5000,10000,20000"

# Path to input/output
PATH_INPUT="simulated_data/categorical/normal"
PATH_OUTPUT="results/categorical/normal/FCI"

PYTHON_SCRIPT="baselines/FCI/normal/run_fci.py"

for NAME in "${MODELS[@]}"; do
  for REP in $REPLICATES; do

    echo "▶ Running FCI: model=$NAME, rep_idx=$REP"

    python "$PYTHON_SCRIPT" \
      --name "$NAME" \
      --sample_sizes "$SAMPLE_SIZES" \
      --rep_idx "$REP" \
      --path_input "$PATH_INPUT" \
      --path_output "$PATH_OUTPUT"

  done
done
