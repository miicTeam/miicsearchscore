# ==============================================================================
# File        : scoring_metrics.R
# Description : Evaluation metrics for graph structure learning.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne Université)
# Created on  : 2025-05-02
# Version     : 1.0.0
#
# Dependencies:
#   - None
#
# Notes:
#   - Computes F-score, Precision, and Recall between predicted and true graphs.
#
# License     : GPL (>= 3)
# ==============================================================================

#' Computes F-score, precision and recall between a true and a predicted adjacency matrix.
#'
#' This function compares a ground truth graph (`adj_true`) with a predicted one (`adj_test`)
#' and counts:
#'   - True Positives (tp): correctly predicted edges (and orientations when applicable)
#'   - False Negatives (fn): missed edges (present in truth, absent in prediction)
#'   - False Positives (fp): edges predicted but absent in ground truth
#'   - Misoriented edges (mo): wrong orientation of a directed edge
#'
#' The F-score penalizes both false positives and orientation errors.
#'
#' @param adj_true The ground truth adjacency matrix (same format as prediction).
#' @param adj_test The predicted adjacency matrix to evaluate.
#' @return A named numeric vector with F-score, Precision, and Recall.

compute_fscore_metrics <- function(adj_true, adj_test) {
  # Ensure consistent node ordering
  node_names <- colnames(adj_true)
  adj_test <- adj_test[node_names, node_names]
  
  # Extract values from lower triangle (excluding diagonal)
  idx <- lower.tri(adj_true)
  true_vals <- adj_true[idx]
  test_vals <- adj_test[idx]
  
  # Exact true positives: predicted value equals true value and is not zero
  tp_exact <- (test_vals == true_vals) & (true_vals != 0)
  tp <- sum(tp_exact)
  
  # Additional true positives: if true value is 1 (undirected), any non-zero prediction is accepted
  general_tp <- (true_vals == 1) & (test_vals != 0) & (!tp_exact)
  tp <- tp + sum(general_tp)
  
  # False negatives: edge present in true but missing in prediction
  fn <- sum((true_vals != 0) & (test_vals == 0))
  
  # Misoriented edges: wrong direction or type, excluding undirected cases
  mo <- sum((true_vals != 0) & (test_vals != 0) & (test_vals != true_vals) & (true_vals != 1))
  
  # False positives: predicted edge where none should exist
  fp <- sum((true_vals == 0) & (test_vals != 0))
  
  # Precision, Recall, F1 Score
  if (tp == 0) {
    precision <- 0
    recall <- 0
    fscore <- 0
  } else {
    precision <- tp / (tp + fp + mo)
    recall <- tp / (tp + fn)
    fscore <- (2 * precision * recall) / (precision + recall)
  }
  
  return(c(Fscore = fscore, Precision = precision, Recall = recall))
}

