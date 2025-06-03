#!/bin/bash

# ==============================================================================
# File        : run_all_non_linear.sh
# Description : Runs DAG-GNN across all settings for simulated
#               non-linear data (n_nodes ∈ {50,150}, avg_degree ∈ {3,5},
#               sample_sizes ∈ {100,...,20000}, rep_idx ∈ 1:30).
#
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - Python environment with DAG-GNN
#   - simulated data under simulated_data/continuous/non_linear/
#
# License     : GPL (>= 3)
# ==============================================================================

# Parameters
N_NODES_LIST=(50 150)
AVG_DEGREE_LIST=(3 5)
SAMPLE_SIZES="100,250,500,1000,5000,10000,20000"
REPLICATES=$(seq 1 30)
IDX_PATH=0
PT_INPUT="simulated_data/continuous/non_linear"
PATH_RESULTS_ROOT="results/continuous/non_linear/DAGGNN"

# Python script path (update if needed)
PYTHON_SCRIPT="baselines/DAGGNN/__main__.py"

# Loop over all combinations
for N_NODES in "${N_NODES_LIST[@]}"; do
  for DEG in "${AVG_DEGREE_LIST[@]}"; do
    for REPLICA in $REPLICATES; do

      echo "▶ Running DAGGNN: nodes=$N_NODES, degree=$DEG, replica=$REPLICA, samples=$SAMPLE_SIZES"

      python $PYTHON_SCRIPT \
        "$N_NODES" "$DEG" "$SAMPLE_SIZES" "$REPLICA" "$PT_INPUT" "$PATH_RESULTS_ROOT"

    done
  done
done
