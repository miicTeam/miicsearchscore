#!/bin/bash

# ==============================================================================
# File        : run_all_categorical_bootstrap.sh
# Description : Runs FCI on simulated categorical data using
#               bootstrap replicates (b ∈ 1:30), with latent variable masking.
#               Replicates are selected from selected_replicas.txt for each model.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - Python environment with FCI
#   - File: selected_replicas.txt
#   - simulated data under simulated_data/categorical/bootstrap/
#
# License     : GPL (>= 3)
# ==============================================================================

MODELS=("Alarm" "Insurance" "Barley" "Mildew")
SAMPLE_SIZES="100,250,500,1000,5000,10000,20000"
BOOTSTRAP_REPS=$(seq 1 30)

PATH_INPUT="simulated_data/categorical/bootstrap"
PATH_OUTPUT="results/categorical/bootstrap/FCI"
REPLICA_FILE="simulated_data/categorical/bootstrap/selected_replicas.txt"
PYTHON_SCRIPT="baselines/FCI/bootstrap/run_fci_bootstrap.py"

for NAME in "${MODELS[@]}"; do
  # Read replicate ID from selected_replicas.txt
  REPLICA_ID=$(awk -v model="$NAME" '$1 == model {print $2}' "$REPLICA_FILE")

  if [ -z "$REPLICA_ID" ]; then
    echo "[ERROR] No replicate ID found for model: $NAME"
    continue
  fi

  for B in $BOOTSTRAP_REPS; do
    echo "▶ Running FCI bootstrap: model=$NAME, rep_idx=$REPLICA_ID, b=$B"

    python "$PYTHON_SCRIPT" \
      --name "$NAME" \
      --sample_sizes "$SAMPLE_SIZES" \
      --rep_idx "$REPLICA_ID" \
      --b "$B" \
      --path_input "$PATH_INPUT" \
      --path_output "$PATH_OUTPUT"
  done
done
