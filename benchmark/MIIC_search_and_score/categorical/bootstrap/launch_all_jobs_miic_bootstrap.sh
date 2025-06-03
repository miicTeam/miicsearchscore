#!/bin/bash

# Base directory
BASE_DIR="/mnt/beegfs/home/nlagrang/stagein/nlagrang/job_scripts/categorical/bootstrap/miic"
echo "==> Checking directory: $BASE_DIR"
    
# Find all .slurm files inside the model directory (recursively)
find "$BASE_DIR" -name "*.slurm" | while read -r script; do
    echo "Submitting: $script"
    sbatch "$script"
done