library(readr)

# Parameters
names <- c("Alarm", "Insurance", "Barley", "Mildew")
sample_groups <- list(
  small   = c("100", "250", "500", "1000"),
  "5000"  = c("5000"),
  "10000" = c("10000"),
  "20000" = c("20000")
)

output_dir <- "job_scripts/FCI/categorical/bootstrap"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

`%+%` <- function(a, b) paste0(a, b)  # String concatenation shortcut

for (name in names) {
  m_id <- which(names == name)
  
  for (sample_suffix in names(sample_groups)) {
    sample_sizes <- sample_groups[[sample_suffix]]
    sample_str <- paste(sample_sizes, collapse = ",")
    max_sample <- max(as.numeric(sample_sizes))
    
    n_threads <- if (max_sample >= 10000) 20 else 16
    mem <- "4G"
    
    script_dir <- file.path(output_dir, name)
    dir.create(script_dir, recursive = TRUE, showWarnings = FALSE)
    
    script_name <- file.path(script_dir, paste0("run_bootstrap_array_", sample_str, ".slurm"))
    job_name <- paste0(name, "_", sample_suffix, "_bootstrap")
    
    script_content <- c(
      "#!/bin/bash",
      "#SBATCH --job-name=" %+% job_name,
      "#SBATCH --nodes=1",
      "#SBATCH --ntasks=1",
      "#SBATCH --cpus-per-task=" %+% n_threads,
      "#SBATCH --mem=" %+% mem,
      "#SBATCH --time=48:00:00",
      "#SBATCH --partition=recherche_batch",
      "#SBATCH --array=1-30",
      "#SBATCH --output=" %+% job_name %+% "_%A_%a.out",
      "#SBATCH --error=" %+% job_name %+% "_%A_%a.err",
      "",
      "source ~/.bashrc",
      "conda activate conda_envs/r_env",
      "",
      "# Parameters",
      "NAME=\"" %+% name %+% "\"",
      "SAMPLE_SIZES=\"" %+% sample_str %+% "\"",
      "M_ID=" %+% m_id,
      "B=${SLURM_ARRAY_TASK_ID}",
      "",
      "# Read replicate ID from selected_replicas.txt",
      "REPLICA_ID=$(awk -v model=\"$NAME\" '$1 == model {print $2}' selected_replicas.txt)",
      "",
      "echo \"[$(date)] Launching bootstrap $B with $NAME, replicate $REPLICA_ID, samples $SAMPLE_SIZES\"",
      "",
      "SCRATCH_DIR=\"/mnt/beegfs/tmp/nlagrang/scratch_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}\"",
      "mkdir -p $SCRATCH_DIR",
      "PATH_OUTPUT=\"results/categorical/bootstrap/FCI\"",
      "",
      "# 1. Generate bootstrap data",
      "Rscript baselines/FCI/bootstrap/simulate_categorical_bootstrap_data_hpc.R \\",
      "  \"$NAME\" \"$M_ID\" \"$SAMPLE_SIZES\" \"$REPLICA_ID\" \"$B\" \"$SCRATCH_DIR\"",
      "",
      "# 2. Run FCI inference",
      "conda activate conda_envs/causal_env",
      "python baselines/FCI/bootstrap/run_fci_bootstrap.py \\",
      "  --name \"$NAME\" --sample_sizes \"$SAMPLE_SIZES\" --rep_idx \"$REPLICA_ID\" --b \"$B\" --path_input \"$SCRATCH_DIR\", --path_output \"$PATH_OUTPUT\"",
      "",
      "# 3. Cleanup",
      "echo \"[$(date)] Cleaning $SCRATCH_DIR\"",
      "rm -rf \"$SCRATCH_DIR\"",
      "echo \"[$(date)] Done.\""
    )
    
    write_lines(script_content, file = script_name)
  }
}
