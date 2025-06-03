#!/bin/bash

# ==============================================================================
# File        : run_all.sh
# Description : Master launcher for FCI benchmark runs on data types:
#               - Categorical
#               - Categorical with bootstrap
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

set -e  # Exit on first error

echo "=== Running FCI on categorical normal datasets ==="
bash baselines/FCI/normal/run_all_categorical.sh

echo "=== Running FCI on categorical bootstrap datasets ==="
bash baselines/FCI/bootstrap/run_all_categorical_bootstrap.sh

echo "✅ All FCI runs completed."
