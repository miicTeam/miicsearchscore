#!/bin/bash

# ==============================================================================
# File        : run_all_linear_gaussian.sh
# Description : Runs GFCI across all settings for simulated
#               linear Gaussian data (n_nodes ∈ {50,150}, avg_degree ∈ {3,5},
#               sample_sizes ∈ {100,...,20000}, rep_idx ∈ 1:30).
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-28
# Version     : 1.0.0
#
# Dependencies:
#   - Python 3.8+
#   - pandas, numpy
#   - py-tetrad
#   - JAVA_HOME correctly set
#   - Input data: benchmark/simulated_data/continuous/linear_gaussian
#
# License     : GPL (>= 3)
# ==============================================================================

echo "▶ Running GFCI pipeline on linear data"
python run_gfci.py linear
