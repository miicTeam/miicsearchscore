#!/bin/bash

# ==============================================================================
# File        : run_all.sh
# Description : Master launcher for DAG-GNN benchmark runs on data types:
#               - Linear Gaussian
#               - Non-linear
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - Scripts: run_all_linear_gaussian.sh, run_all_non_linear.sh
#
# License     : GPL (>= 3)
# ==============================================================================

set -e  # Stop if any command fails

echo "=== Launching DAGGNN on linear Gaussian simulations ==="
bash baselines/DAGGNN/linear_gaussian/run_all_linear_gaussian.sh

echo "=== Launching DAGGNN on non-linear simulations ==="
bash baselines/DAGGNN/non_linear/run_all_non_linear.sh

echo "✅ All DAGGNN runs completed."
