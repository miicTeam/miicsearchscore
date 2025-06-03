library(readr)

node_counts <- c("50", "150")
average_degrees <- c("3", "5")
sample_groups <- list(
  small  = c("100", "250", "500", "1000"),
  medium = c("5000"),
  large  = c("10000"),
  huge   = c("20000")
)
modes <- c("NL")
n_replicates <- 30

path_results_root <- "results/continuous/non_linear/DAGGNN" 

output_dir <- "job_scripts/DAGGNN/non_linear"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

for (n_nodes in node_counts) {
  for (degree in average_degrees) {
    for (mode in modes) {
      for (group_name in names(sample_groups)) {
        
        sample_sizes <- sample_groups[[group_name]]
        sample_str <- paste(sample_sizes, collapse = ",")
        sample_suffix <- if (length(sample_sizes) == 1) sample_sizes else group_name
        max_sample <- max(as.numeric(sample_sizes))
        int_nodes <- as.numeric(n_nodes)
        
        # Threads
        ppn <- if (int_nodes >= 150 && max_sample >= 10000) {
          4
        } else if (int_nodes >= 100 || max_sample >= 5000) {
          2
        } else {
          1
        }
        
        # Memory
        mem <-"8gb"
        
        # Walltime
        walltime <- "24:00:00"

        job_name <- paste0(mode, "_N", n_nodes, "_", degree, "_", sample_suffix, "_array")
        script_name <- file.path(output_dir, paste0(job_name, ".sh"))
        
        script_content <- c(
          "#!/bin/bash",
          paste("#PBS -N", job_name),
          paste("#PBS -l walltime=", walltime, sep=""),
          paste("#PBS -l mem=", mem, sep=""),
          paste("#PBS -l nodes=1:ppn=", ppn, sep=""),
          paste("#PBS -t 1-", n_replicates, sep=""),
          "#PBS -j oe",
          "#PBS -q batch",
          "",
          "source ~/.bashrc",
          "",
          paste0("N_NODES=", n_nodes),
          paste0("AVG_DEGREE=", degree),
          paste0("SAMPLE_SIZES=\"", sample_str, "\""),
          paste0("N_THREADS=", ppn),
          paste0("PATH_RESULTS_ROOT=", path_results_root),
          "REPLICA_ID=${PBS_ARRAYID}",
          "",
          "echo \"Launching replicate $REPLICA_ID with $N_NODES nodes, degree $AVG_DEGREE, samples $SAMPLE_SIZES\"",
          "",
          "Rscript /baselines/DAGGNN/non_linear/simulate_nonlinear_data_hpc.R \\",
          "  \"$N_NODES\" \"$AVG_DEGREE\" \"$SAMPLE_SIZES\" \"$REPLICA_ID\" \"$TMPDIR\"",
          "",
          "conda activate py39",
          "",
          paste0("python baselines/DAGGNN/__main__.py \\"),
          paste0("  \"$N_NODES\" \"$AVG_DEGREE\" \"$SAMPLE_SIZES\" \"$REPLICA_ID\" \"$PATH_RESULTS_ROOT\" \"$TMPDIR\"")
        )
        
        write_lines(script_content, file = script_name)
      }
    }
  }
}
