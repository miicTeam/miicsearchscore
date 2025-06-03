library(readr)

# Parameters
names <- c("Alarm", "Insurance", "Barley", "Mildew")
sample_groups <- list(
  small = c("100", "250", "500", "1000"),
  "5000" = c("5000"),
  "10000" = c("10000"),
  "20000" = c("20000")
)

# Output directory
output_dir <- "job_scripts/categorical/normal/miic"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

`%+%` <- function(a, b) paste0(a, b)

for (name in names) {
  for (sample_suffix in names(sample_groups)) {
    sample_sizes <- sample_groups[[sample_suffix]]
    
    sample_str <- paste(sample_sizes, collapse = ",")
    max_sample <- max(as.numeric(sample_sizes))
    m_id <- which(names == name)
    
    # Threads
    n_threads <- if (max_sample >= 10000) 20 else 16
    mem <- "2G"
    
    script_dir <- file.path(output_dir, name)
    dir.create(script_dir, recursive = TRUE, showWarnings = FALSE)
    script_name <- file.path(script_dir, paste0(paste0("run_array_",sample_str),".slurm"))
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
      "NAME=\"" %+% name %+% "\"",
      "SAMPLE_SIZES=\"" %+% sample_str %+% "\"",
      "N_THREADS=" %+% n_threads,
      "REPLICA_ID=${SLURM_ARRAY_TASK_ID}",
      "M_ID=" %+% m_id,
      "",
      "echo \"[$(date)] Launching replicate $REPLICA_ID with $NAME, samples $SAMPLE_SIZES, threads $N_THREADS\"",
      "",
      "Rscript /mnt/beegfs/home/nlagrang/stagein/nlagrang/run_miic_search_score_categorical.R \\",
      "  \"$NAME\" \"$M_ID\" \"$SAMPLE_SIZES\" \"$N_THREADS\" \"$REPLICA_ID\""
    )
    
    write_lines(script_content, file = script_name)
  }
}
