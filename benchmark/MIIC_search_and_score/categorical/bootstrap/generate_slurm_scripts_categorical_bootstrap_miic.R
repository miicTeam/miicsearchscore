library(readr)

models <- c("Alarm", "Insurance", "Barley", "Mildew")
model_ids <- setNames(1:4, models)

sample_groups <- list(
  small  = c(100, 250),
  medium = c(500, 1000),
  large  = c(5000, 10000),
  huge   = c(20000)
)

n_threads <- 16
n_bootstraps <- 30
partition <- "recherche_batch"
time_limit <- "48:00:00"
memory <- "2G"

# Output directory for generated SLURM scripts
output_dir <- "job_scripts/categorical/bootstrap/miic"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

for (model in models) {
  for (group in names(sample_groups)) {
    sizes <- sample_groups[[group]]
    max_sample <- max(as.numeric(sizes))
    n_threads <- if (max_sample >= 10000) 20 else 16
    
    sizes_str <- paste(sizes, collapse = ",")
    script_name <- sprintf("%s_%s_bootstrap_array.slurm", model, group)
    script_path <- file.path(output_dir, script_name)
    
    script_lines <- c(
      "#!/bin/bash",
      sprintf("#SBATCH --job-name=%s_%s_bootstrap", model, group),
      "#SBATCH --nodes=1",
      "#SBATCH --ntasks=1",
      sprintf("#SBATCH --cpus-per-task=%d", n_threads),
      sprintf("#SBATCH --mem=%s", memory),
      sprintf("#SBATCH --time=%s", time_limit),
      sprintf("#SBATCH --partition=%s", partition),
      sprintf("#SBATCH --array=1-%d", n_bootstraps),
      sprintf("#SBATCH --output=%s_%s_bootstrap_%%A_%%a.out", model, group),
      sprintf("#SBATCH --error=%s_%s_bootstrap_%%A_%%a.err", model, group),
      "",
      "source ~/.bashrc",
      "conda activate conda_envs/r_env",
      "",
      sprintf("NAME=\"%s\"", model),
      sprintf("SAMPLE_SIZES=\"%s\"", sizes_str),
      sprintf("N_THREADS=%d", n_threads),
      "B=${SLURM_ARRAY_TASK_ID}",
      "",
      "# Read the replicate ID from selected_replicas.txt",
      "REPLICA_ID=$(awk -v model=\"$NAME\" '$1 == model {print $2}' selected_replicas.txt)",
      "",
      "echo \"[$(date)] Launching bootstrap $B with $NAME, replicate $REPLICA_ID, samples $SAMPLE_SIZES, threads $N_THREADS\"",
      "",
      "Rscript /mnt/beegfs/home/nlagrang/stagein/nlagrang/run_miic_search_score_categorical_bootstrap.R \\",
      "  \"$NAME\" \"$REPLICA_ID\" \"$SAMPLE_SIZES\" \"$N_THREADS\" \"$B\""
    )
    
    writeLines(script_lines, con = script_path)
  }
}

