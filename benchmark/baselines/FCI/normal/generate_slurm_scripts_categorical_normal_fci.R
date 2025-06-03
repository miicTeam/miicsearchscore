library(readr)

# Paramètres
names <- c("Alarm", "Insurance", "Barley", "Mildew")
sample_groups <- list(
  small = c("100", "250", "500", "1000"),
  "5000" = c("5000"),
  "10000" = c("10000"),
  "20000" = c("20000")
)

# Répertoire de sortie des scripts SLURM
output_dir <- "job_scripts/FCI/categorical/normal"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

`%+%` <- function(a, b) paste0(a, b)

for (name in names) {
  for (sample_suffix in names(sample_groups)) {
    sample_sizes <- sample_groups[[sample_suffix]]
    
    sample_str <- paste(sample_sizes, collapse = ",")
    max_sample <- max(as.numeric(sample_sizes))
    m_id <- which(names == name)
    
    # Threads & mémoire
    n_threads <- if (max_sample >= 10000) 20 else 16
    mem <- "2G"
    
    # Génération du script SLURM
    script_dir <- file.path(output_dir, name)
    dir.create(script_dir, recursive = TRUE, showWarnings = FALSE)
    script_name <- file.path(script_dir, paste0("run_array_", sample_str, ".slurm"))
    job_name <- paste0(name, "_", sample_suffix, "_array")
    
    script_content <- c(
      "#!/bin/bash",
      "#SBATCH --job-name=" %+% job_name,
      "#SBATCH --nodes=1",
      "#SBATCH --ntasks=1",
      "#SBATCH --cpus-per-task=" %+% n_threads,
      "#SBATCH --mem=" %+% mem,
      "#SBATCH --time=48:00:00",
      "#SBATCH --partition=recherche_batch",
      "#SBATCH --array=1-50",
      "#SBATCH --output=" %+% job_name %+% "_%A_%a.out",
      "#SBATCH --error=" %+% job_name %+% "_%A_%a.err",
      "",
      "source ~/.bashrc",
      "conda activate conda_envs/r_env",
      "",
      "# Paramètres SLURM",
      "NAME=\"" %+% name %+% "\"",
      "SAMPLE_SIZES=\"" %+% sample_str %+% "\"",
      "REPLICA_ID=${SLURM_ARRAY_TASK_ID}",
      "M_ID=" %+% m_id,
      "",
      "# Répertoire temporaire simulant $SCRATCH",
      "SCRATCH_DIR=\"/mnt/beegfs/tmp/nlagrang/scratch_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}\"",
      "mkdir -p $SCRATCH_DIR",
      "PATH_OUTPUT=\"results/categorical/normal/FCI\"",
      "",
      "echo \"[$(date)] Starting simulation in $SCRATCH_DIR\"",
      "",
      "Rscript /mnt/beegfs/home/nlagrang/stagein/nlagrang/simulate_categorical_data_hpc.R \\",
      "  \"$NAME\" \"$M_ID\" \"$SAMPLE_SIZES\" \"$REPLICA_ID\" \"$SCRATCH_DIR\"",
      "",
      "conda activate conda_envs/causal_env",
      "python /mnt/beegfs/home/nlagrang/stagein/nlagrang/run_fci.py \\",
      "  --name \"$NAME\" --sample_sizes \"$SAMPLE_SIZES\" --rep_idx \"$REPLICA_ID\" --path_input \"$SCRATCH_DIR\",  --path_output \"$PATH_OUTPUT\"",
      "",
      "echo \"[$(date)] Cleaning $SCRATCH_DIR\"",
      "rm -rf \"$SCRATCH_DIR\"",
      "echo \"[$(date)] Done.\""
    )
    
    write_lines(script_content, file = script_name)
  }
}