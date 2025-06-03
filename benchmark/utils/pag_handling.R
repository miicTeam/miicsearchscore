# ==============================================================================
# File        : pag_handling.R
# Description : Functions to generate PAGs from DAGs and convert to MIIC format.
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-02
# Version     : 1.0.0
#
# Dependencies:
#   - pcalg, RBGL
#
# Notes:
#   - This file contains tools to estimate PAGs with latent variables
#     and convert PAG adjacency matrices to MIIC encoding.
#
# License     : GPL (>= 3)
# ==============================================================================

#' Generates a PAG adjacency matrix from a DAG with specified latent variables.
#'
#' This function:
#'   1. Sorts the DAG topologically.
#'   2. Computes its true covariance matrix using random edge weights.
#'   3. Transforms it into a correlation matrix.
#'   4. Uses `pcalg::dag2pag` to infer the PAG structure, treating some variables as latent.
#'   5. Extracts the adjacency matrix of the PAG (partial ancestral graph), removing latent nodes.
#'
#' @param dag A DAG adjacency matrix (0/1) with named rows/columns.
#' @param latent A character vector of latent variable names.
#' @seealso generate_covariance_from_dag
#' @return A PAG adjacency matrix (0/1/2/3) excluding latent variables.

generate_pag_adjacency <- function(dag, latent) {
  if (!is.matrix(dag)) stop("'dag' must be a matrix.")
  if (!is.character(latent)) stop("'latent' must be a character vector.")
  # Convert DAG matrix to graphNEL
  g <- as(dag, "graphNEL")
  
  # Topological sort to ensure causal ordering
  sorted_nodes <- RBGL::tsort(g)
  dag_sorted <- dag[sorted_nodes, sorted_nodes]
  g_sorted <- as(dag_sorted, "graphNEL")
  
  # Generate the true covariance matrix (with random weights)
  cov_mat <- generate_covariance_from_dag(g_sorted)
  
  # Convert to correlation matrix
  corr_mat <- cov2cor(cov_mat)
  
  # Indices of latent variables in the sorted node list
  latent_indices <- which(sorted_nodes %in% latent)
  
  # Compute the true PAG using a near-perfect CI test (n=1e9, alpha≈1)
  pag_graph <- pcalg::dag2pag(
    suffStat = list(C = corr_mat, n = 1e9), indepTest = gaussCItest, graph = g_sorted, L = latent_indices, alpha = 0.99999
  )
  
  # Extract adjacency matrix from the PAG (amat = adjacency matrix)
  pag_adj <- pag_graph@amat
  
  # Set proper row and column names
  observed_nodes <- setdiff(sorted_nodes, latent)
  colnames(pag_adj) <- rownames(pag_adj) <- observed_nodes
  
  return(pag_adj)
}

#' Converts a PAG adjacency matrix (from pcalg) into the MIIC adjacency matrix format.
#'
#' This function maps the `amat` encoding from `pcalg` into MIIC's internal edge type codes:
#'   - X <-> Y (bidirected): 6   in both directions
#'   - X — Y (undirected):  1   in both directions
#'   - X -> Y (directed):   2   in direction i → j and -2 for j ← i
#'
#' @param pag A square PAG adjacency matrix (values 0/1/2/3, as in `true.pag@amat`) from `pcalg`.
#' @return A square matrix with MIIC-style edge encoding (0, 1, ±2, 6).

convert_pag_to_miic_adjacency <- function(pag) {
  if (!all(pag %in% 0:3)) {
    stop("PAG adjacency matrix must contain only values 0, 1, 2, or 3.")
  }
  if (is.null(colnames(pag)) || is.null(rownames(pag))) {
    stop("Input PAG matrix must have named rows and columns.")
  }
  
  node_names <- colnames(pag)
  n <- length(node_names)
  
  # Initialize MIIC-style adjacency matrix
  adj_miic <- matrix(0, nrow = n, ncol = n)
  colnames(adj_miic) <- rownames(adj_miic) <- node_names
  
  # Traverse only the upper triangle (symmetric treatment)
  for (i in seq_len(n)) {
    for (j in seq_len(i - 1)) {
      vx <- pag[j, i]  # Edge mark from j to i (vx = pag[j, i])
      vy <- pag[i, j]  # Edge mark from i to j (vy = pag[i, j])
      
      # No edge
      if (vx == 0 && vy == 0) {
        next
        
        # Bidirected edge: X <-> Y
      } else if (vx == 2 && vy == 2) {
        adj_miic[i, j] <- 6
        adj_miic[j, i] <- 6
        
        # Undirected edge: X — Y
      } else if (vx == 3 && vy == 3) {
        adj_miic[i, j] <- 1
        adj_miic[j, i] <- 1
        
        # Circle-circle: X o—o Y (treated as undirected)
      } else if (vx == 1 && vy == 1) {
        adj_miic[i, j] <- 1
        adj_miic[j, i] <- 1
        
        # X ← Y (j → i)
      } else if (vx == 2 && (vy == 1 || vy == 3)) {
        adj_miic[i, j] <- -2
        adj_miic[j, i] <- 2
        
        # X → Y (i → j)
      } else if (vy == 2 && (vx == 1 || vx == 3)) {
        adj_miic[i, j] <- 2
        adj_miic[j, i] <- -2
   
        # X o— Y or X —o Y: treated as undirected
      } else if ((vx == 1 && vy == 3) || (vx == 3 && vy == 1)) {
        adj_miic[i, j] <- 1
        adj_miic[j, i] <- 1
        
        # One side is NULL (edge not fully formed)
      } else if (vx == 0 || vy == 0) {
        next
        
        # Unhandled case: issue a warning
      } else {
        warning(sprintf("Unhandled edge: %s ↔ %s with (vx = %d, vy = %d)", node_names[j], node_names[i], vx, vy))
      }
    }
  }
  
  return(adj_miic)
}
