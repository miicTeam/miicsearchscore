source("utils/scoring_metrics.R")
source("utils/graph_modeling.R")
source("utils/pag_handling.R")
source("utils/plot_metrics.R")

run_plot_pipeline <- function(domain, data_type, X, degree = NULL, nb_rep, N, tag_L, names_algo, cols_algo) {
  for (x in X) {
    degrees <- if (is.null(degree)) list(NULL) else degree
    for (dg in degrees) {
      cat("Processing:", domain, data_type, x, if (!is.null(dg)) paste("degree", dg), "\n")
      
      colnames_list <- unlist(lapply(names_algo, function(algo) {
        sapply(tag_L, function(l) {
          sapply(1:nb_rep, function(i) paste(algo, l, i, sep = "_"))
        })
      }))
      
      fs <- pre <- rec <- matrix(nrow = length(N), ncol = length(colnames_list))
      colnames(fs) <- colnames(pre) <- colnames(rec) <- colnames_list
      
      idx <- 1
      for (n in N) {
        for (l in tag_L) {
          for (i in 1:nb_rep) {
            base_data <- if (!is.null(dg)) file.path("simulated_data", domain, data_type, x, dg, n) else file.path("simulated_data", domain, data_type, x, n)
            base_graph <- if (!is.null(dg)) file.path("simulated_data", "graphs", domain, x, dg) else file.path("simulated_data", "graphs", domain, x)
            
            input_file <- file.path(base_data, paste0("input_", l, "_", i, ".csv"))
            graph_file <- file.path(base_graph, paste0("adj_cpdag", if (!is.null(dg)) paste0("_", i) else "", ".csv"))
            if (!file.exists(input_file) || !file.exists(graph_file)) next
            
            input <- read.csv(input_file)
            nm_input <- colnames(input)
            cpdag <- as.matrix(read.csv(graph_file))
            
            pag <- if (l == "0L") cpdag else {
              pag_path <- file.path(base_graph, paste0("pag_", l, "_", i, ".csv"))
              if (!file.exists(pag_path)) next
              read.csv(pag_path) |> as.matrix()
            }
            rownames(pag) <- colnames(pag)
            if (l != "0L") pag <- convert_pag_to_miic_adjacency(pag)
            
            score_algo <- function(adj, name) {
              colname <- paste(name, l, i, sep = "_")
              sc <- compute_fscore_metrics(pag, adj)
              fs[idx, colname] <<- sc[1]
              pre[idx, colname] <<- sc[2]
              rec[idx, colname] <<- sc[3]
            }
            
            for (algo in names_algo) {
              fname <- switch(algo,
                              "miic_search_and_score" = paste0("adj_sc_node_and_edge_", l, "_", i, ".csv"),
                              "miic" = paste0("adj_miic_", l, "_", i, ".csv"),
                              "M3HC" = paste0("adj_m3hc_", l, "_", i, ".csv"),
                              "GFCI" = paste0("adj_GFCI_", l, "_", i, ".csv"),
                              "DAGGNN" = paste0("adj_DAGGNN_", l, "_", i, ".csv"),
                              "FCI" = paste0("adj_FCI_", l, "_", i, ".csv"))
              
              pname <- switch(algo,
                              "miic_search_and_score" = "MIIC_search_and_score",
                              "miic" = "MIIC_search_and_score",
                              "M3HC" = "M3HC",
                              "GFCI" = "GFCI",
                              "DAGGNN" = "DAGGNN",
                              "FCI" = "FCI")
              
              path <- file.path("results", domain, data_type, pname, x, if (!is.null(dg)) dg else "", n, fname)
              if (!file.exists(path)) next
              
              if (algo == "DAGGNN") {
                adj <- read.csv(path, header = FALSE)
                adj <- as.matrix(adj)
                colnames(adj) <- rownames(adj) <- nm_input
                adj <- adjacency_to_miic(adj)
              } else if (algo == "FCI") {
                adj <- as.matrix(read.csv(path, row.names = 1, check.names = FALSE))
                adj <- convert_pag_fci_to_miic_adjacency(adj)
              } else if (algo == "M3HC" || algo == "GFCI") {
                adj <- as.matrix(read.csv(path, header = FALSE))
                colnames(adj) <- rownames(adj) <- nm_input
                adj <- convert_pag_to_miic_adjacency(adj)
              } else {
                adj <- as.matrix(read.csv(path, header = TRUE))
                colnames(adj) <- rownames(adj) <- nm_input
              }
              
              score_algo(adj, algo)
            }
          }
        }
        idx <- idx + 1
      }
      
      metrics_dir <- file.path("results","metrics", domain, data_type, x, if (!is.null(dg)) dg else "")
      plots_dir <- file.path("results", "plots", domain, data_type, x, if (!is.null(dg)) dg else "")
      dir.create(metrics_dir, recursive = TRUE, showWarnings = FALSE)
      dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)
      
      write.csv(fs, file.path(metrics_dir, "fscore.csv"), row.names = FALSE)
      write.csv(pre, file.path(metrics_dir, "precision.csv"), row.names = FALSE)
      write.csv(rec, file.path(metrics_dir, "recall.csv"), row.names = FALSE)
      
      rs <- list(fscore = fs, pre = pre, rec = rec)
      for (l in tag_L) {
        cn_algo_L <- sapply(names_algo, function(algo) paste(algo, l, sep = "_"))
        plot_base <- file.path(plots_dir, paste0("plot_", l))
        plot_metrics(rs, N, cn_algo_L, paste0(plot_base, "_precision_recall.png"), nb_rep, cols_algo)
      }
    }
  }
}

run_plot_pipeline("continuous", "linear_gaussian", X = c("N50", "N150"), degree = c("3", "5"), nb_rep = 30,
                  N = c("100", "250", "500", "1000", "5000", "10000", "20000"), tag_L = c("0L", "10L", "20L"),
                  names_algo = c("M3HC", "miic", "miic_search_and_score", "GFCI", "DAGGNN"), cols_algo = c(
                    "M3HC" = "darkgrey",
                    "miic" = "blue",
                    "miic_search_and_score" = "red",
                    "GFCI" = "purple",
                    "DAGGNN" = "green"))

run_plot_pipeline("continuous", "non_linear", X = c("N50", "N150"), degree = c("3", "5"), nb_rep = 30,
                  N = c("100", "250", "500", "1000", "5000", "10000", "20000"), tag_L = c("0L", "10L", "20L"),
                  names_algo = c("M3HC", "miic", "miic_search_and_score", "GFCI", "DAGGNN"), cols_algo = c(
                    "M3HC" = "darkgrey",
                    "miic" = "blue",
                    "miic_search_and_score" = "red",
                    "GFCI" = "purple",
                    "DAGGNN" = "green"))

run_plot_pipeline("categorical", "normal", X = c("Alarm", "Insurance", "Barley", "Mildew"), nb_rep = 50,
                  N = c("100", "250", "500", "1000", "5000", "10000", "20000"), tag_L = c("0L", "10L", "20L"),
                  names_algo = c("miic", "miic_search_and_score", "FCI"), cols_algo = c(
                    "FCI" = "darkgrey",
                    "miic" = "blue",
                    "miic_search_and_score" = "red"))

nb_rep <- 30
tag_L <- c("0L", "10L", "20L")
N <- c("100", "250", "500", "1000", "5000", "10000", "20000")
names_algo <- c("miic", "miic_search_and_score", "FCI")
X <- c("Alarm","Insurance","Barley","Mildew")
replica_indices <- read.table("simulated_data/categorical/bootstrap/selected_replicas.txt", header = TRUE, sep = "\t")
replica_map <- setNames(replica_indices$rep_id, replica_indices$model)

missing_log <- "results/categorical/bootstrap/FCI/missing_files_log.txt"
if (file.exists(missing_log)) file.remove(missing_log)

log_missing <- function(path) {
  cat(path, file = missing_log, append = TRUE, sep = "\n")
}

for (x in X) {
  idx_dataset <- replica_map[x]
  
  colnames_list <- unlist(lapply(names_algo, function(algo) {
    sapply(tag_L, function(l) {
      sapply(1:nb_rep, function(i) paste(algo, l, i, sep = "_"))
    })
  }))
  
  cat("Processing: categorical bootstrap", x, "\n")
  
  fs <- pre <- rec <- matrix(nrow = length(N), ncol = length(colnames_list))
  colnames(fs) <- colnames(pre) <- colnames(rec) <- colnames_list
  
  idx <- 1
  for (n in N) {
    for (l in tag_L) {
      for (i in 1:nb_rep) {
        
        base_graph <- file.path("simulated_data", "graphs", "categorical", x)
        
        cpdag_path <- file.path(base_graph, "adj_cpdag.csv")
        if (!file.exists(cpdag_path)) {
          log_missing(cpdag_path)
          next
        }
        cpdag <- read.csv(cpdag_path, row.names = 1, check.names = FALSE) |> as.matrix()
        
        pag <- if (l == "0L") cpdag else {
          pag_path <- file.path(base_graph, paste0("pag_", l, "_", idx_dataset, ".csv"))
          if (!file.exists(pag_path)) {
            log_missing(pag_path)
            next
          }
          read.csv(pag_path, row.names = 1, check.names = FALSE) |> as.matrix()
        }
        rownames(pag) <- colnames(pag)
        if(l!="0L"){
          pag <- convert_pag_to_miic_adjacency(pag)
        }
        
        score_algo <- function(adj, name) {
          colname <- paste(name, l, i, sep = "_")
          sc <- compute_fscore_metrics(pag, adj)
          fs[idx, colname] <<- sc[1]
          pre[idx, colname] <<- sc[2]
          rec[idx, colname] <<- sc[3]
        }
        
        fname_suffix <- paste0("_", l, "_", idx_dataset, "_", i, ".csv")
        
        try_score <- function(path, name) {
          if (file.exists(path)) {
            adj <- as.matrix(read.csv(path, row.names = 1, check.names = FALSE))
            if(name=="FCI"){
              adj <- convert_pag_fci_to_miic_adjacency(adj)
            }
            score_algo(adj, name)
          } else {
            log_missing(path)
          }
        }
        
        try_score(file.path("results", "categorical", "bootstrap", "MIIC_search_and_score", x, n, paste0("adj_sc_node_and_edge", fname_suffix)), "miic_search_and_score")
        try_score(file.path("results", "categorical", "bootstrap", "MIIC_search_and_score", x, n, paste0("adj_miic", fname_suffix)), "miic")
        try_score(file.path("results", "categorical", "bootstrap", "FCI", x, n, paste0("adj_FCI", fname_suffix)), "FCI")
      }
    }
    idx <- idx + 1
  }
  
  metrics_dir <- file.path("results", "metrics", "categorical", "bootstrap", x)
  plots_dir <- file.path("results", "plots", "categorical", "bootstrap", x)
  
  dir.create(metrics_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)
  
  write.csv(fs, file.path(metrics_dir, "fscore.csv"), row.names = FALSE)
  write.csv(pre, file.path(metrics_dir, "precision.csv"), row.names = FALSE)
  write.csv(rec, file.path(metrics_dir, "recall.csv"), row.names = FALSE)
  
  rs <- list(fscore = fs, pre = pre, rec = rec)

    for (l in tag_L) {
    cn_algo_L <- sapply(names_algo, function(algo) paste(algo, l, sep = "_"))
    plot_base <- file.path(plots_dir, paste0("plot_", l))
    plot_metrics(rs, N, cn_algo_L, paste0(plot_base, "_precision_recall.png"), nb_rep, c(
      "FCI" = "darkgrey",
      "miic" = "blue",
      "miic_search_and_score" = "red"))
  }
}
