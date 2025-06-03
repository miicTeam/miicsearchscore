#' MIIC_search&score pipeline for ancestral graph discovery
#'
#' This function executes the complete two-step \strong{MIIC_search&score} pipeline
#' on a given dataset. It starts from the initial adjacency matrix learned by
#' MIIC with latent orientation and applies:
#' \enumerate{
#'   \item Node-level edge pruning via local conditioning set optimization.
#'   \item Greedy edge orientation via mutual information deltas.
#' }
#'
#' The method builds a cache of multivariate information values to avoid redundant
#' computations across both steps. It returns the final adjacency matrix representing
#' the inferred ancestral graph.
#'
#' @param data A data.frame containing observational data. Each column is a variable.
#' @param n_threads Integer indicating the number of threads to use in the initial MIIC call.
#'
#' @return A square adjacency matrix in MIIC format:
#'   \describe{
#'     \item{0}{No edge}
#'     \item{1}{Undirected edge}
#'     \item{2/-2}{Directed edge (2 = parent, -2 = child)}
#'     \item{6}{Bidirected edge (latent confounding)}
#'   }
#'
#' @references
#' Lagrange, N. and Isambert, H. (2025).
#' An efficient search-and-score algorithm for ancestral graphs using multivariate information scores.
#' In \emph{Proceedings of the 42nd International Conference on Machine Learning (ICML 2025)}.
#'
#' @seealso [apply_node_score_step_1()], [apply_edge_score_step_2()], [miic()]
#' @import miic
#' @export


run_miic_searchscore <- function(data, n_threads = 1){
  set.seed(0) 
  result_miic <- miic(data, latent = "orientation", propagation = TRUE, consistent = "orientation", n_threads = n_threads)
  
  # Build hash table of information gains
  summary <- result_miic$summary
  summary <- summary[summary$type == "P", ]
  hash_table <- new.env()
  adj_miic <- result_miic$adj_matrix
  
  for (i in seq_len(nrow(summary))) {
    X <- summary[i, "x"]
    Y <- summary[i, "y"]
    cond <- summary[i, "ai"]
    info_val <- summary[i, "info_shifted"]
    key <- if (!is.na(cond)) digest(c(sort(c(X, Y)), sort(cond))) else digest(sort(c(X, Y)))
    hash_table[[key]] <- info_val
  }
  
  # Step 1: Node-level conditioning set selection and edge pruning
  step1_result <- apply_node_score_step_1(adj_miic, data, hash_table)
  adj_step1_node_score <- step1_result$adj
  hash_table <- step1_result$hash_table
  
  # Step 2: Greedy edge reorientation using mutual information deltas
  step2_result  <- apply_edge_score_step_2(adj_step1_node_score, data, hash_table)
  adj_step2_edge_score <- step2_result$adj
  
  return(adj_step2_edge_score)
}