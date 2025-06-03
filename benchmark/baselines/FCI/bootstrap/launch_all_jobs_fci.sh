#!/bin/bash

# Base directory
BASE_DIR="job_scripts/FCI/categorical/bootstrap"

# List of model names (subdirectories)
MODELS=("Alarm" "Barley" "Insurance" "Mildew")

# Loop through each model directory
for MODEL in "${MODELS[@]}"; do
    MODEL_DIR="${BASE_DIR}/${MODEL}"

    echo "==> Checking directory: $MODEL_DIR"
    
    # Find all .slurm files inside the model directory (recursively)
    find "$MODEL_DIR" -name "*.slurm" | while read -r script; do
        echo "Submitting: $script"
        sbatch "$script"
    done
done
