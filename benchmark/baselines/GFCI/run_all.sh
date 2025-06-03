#!/bin/bash

# ==============================================================================
# File        : run_all.sh
# Description : Master launcher for GFCI benchmark runs on all data types:
#               - Linear Gaussian
#               - Non-linear
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - run_all_linear_gaussian.sh
#   - run_all_non_linear.sh
#
# License     : GPL (>= 3)
# ==============================================================================

set -e

echo "=== Running GFCI on linear Gaussian data ==="
bash baselines/GFCI/run_all_linear_gaussian.sh

echo "=== Running GFCI on non-linear data ==="
bash baselines/GFCI/run_all_non_linear.sh

echo "✅ All GFCI runs completed."
