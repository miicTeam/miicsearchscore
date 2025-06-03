# ==============================================================================
# File        : graph_modeling.R
# Description : Graph construction and conversion tools (CPT to DAG, DAG to CPDAG, covariance).
#
# Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
# Created on  : 2025-05-02
# Version     : 1.0.0
#
# Dependencies:
#   - pcalg
#   - bnlearn (for CPT input format)
#
# Notes:
#   - This file contains functions to model causal graphs, convert formats,
#     and simulate linear covariance Gaussian matrix.
#
# License     : GPL (>= 3)
# ==============================================================================


library(pcalg)

#' Converts a bnlearn Conditional Probability Table (CPT)
#' into a directed adjacency matrix (edges: parent → child).
#'
#' @param cpt A list of CPTs from a bnlearn object, where each element
#'            contains the parents of a variable.
#' @return A binary adjacency matrix (0/1) indicating directed edges between variables.
adjacency_from_cpt <- function(cpt) {
  variable_names <- names(cpt)
  n_vars <- length(variable_names)
  
  # Initialize an empty square adjacency matrix
  adj_matrix <- matrix(0, nrow = n_vars, ncol = n_vars)
  colnames(adj_matrix) <- rownames(adj_matrix) <- variable_names
  
  # Fill the matrix with directed edges: parent → child
  for (child in variable_names) {
    parents <- cpt[[child]]$parents
    
    if (length(parents) > 0) {
      for (parent in parents) {
        adj_matrix[parent, child] <- 1  # parent → child
        adj_matrix[child, parent] <- 0  # not necessary, but explicit
      }
    }
  }
  
  return(adj_matrix)
}

#' Convert DAG adjacency matrix to MIIC-style oriented matrix
#'
#' @param adj A square adjacency matrix representing a DAG.
#'        Should be binary (0 or 1) with directed edges: adj[i, j] = 1 means i → j.
#' @return A square matrix of the same size with MIIC-style encoding:
#'         - 2 means a directed edge from i to j (i → j)
#'         - -2 means a directed edge from j to i (j → i)
#'         - 0 means no edge
#'         The encoding is symmetric (i.e., adj[i, j] = 2 ⇒ adj[j, i] = -2)
adjacency_to_miic <- function(adj) {
  if (!is.matrix(adj)) stop("Input 'adj' must be a matrix.")
  if (!all(adj %in% c(0, 1))) stop("Adjacency matrix must be binary (0/1).")
  node_names <- colnames(adj)
  n_nodes <- length(node_names)
  
  adj_miic <- matrix(0, nrow = n_nodes, ncol = n_nodes)
  colnames(adj_miic) <- rownames(adj_miic) <- node_names
  
  for (i in seq_len(n_nodes)) {
    for (j in seq_len(n_nodes)) {
      if (i != j && adj[i, j] != 0) {
        edge_ij <- adj[i, j]
        edge_ji <- adj[j, i]
        
        if (edge_ij == 1 && edge_ji == 0) {
          adj_miic[i, j] <- 2   # i → j
          adj_miic[j, i] <- -2
        }
        if (edge_ij == 0 && edge_ji == 1) {
          adj_miic[i, j] <- -2  # j → i
          adj_miic[j, i] <- 2
        }
      }
    }
  }
  
  return(adj_miic)
}

#' Converts a DAG adjacency matrix into a CPDAG adjacency matrix.
#'
#' This function uses `pcalg::dag2cpdag` to compute the Completed Partially Directed Acyclic Graph (CPDAG),
#' and re-encodes the adjacency matrix using the convention adopted by MIIC:
#'   - 2   = directed edge i → j
#'   - -2  = directed edge j ← i
#'   - 1   = undirected edge i — j
#'   - 0   = no edge
#'
#' @param adj A square binary adjacency matrix representing a DAG (0/1, with adj[i, j] = 1 if i → j).
#' @return A square matrix with CPDAG edge annotations (0, 1, 2, -2), following the MIIC format.
adjacency_to_cpdag <- function(adj) {
  if (!is.matrix(adj)) stop("Input 'adj' must be a matrix.")
  if (!all(adj %in% c(0, 1))) stop("Adjacency matrix must be binary (0/1).")
  # Convert the adjacency matrix to a graphNEL object (required by dag2cpdag)
  g_dag <- as(adj, "graphNEL")
  
  # Compute the CPDAG using pcalg
  g_cpdag <- pcalg::dag2cpdag(g_dag)
  
  # Convert back to an adjacency matrix
  cpdag_matrix <- as(g_cpdag, "matrix")
  n <- ncol(cpdag_matrix)
  
  # Re-encode directed edges using MIIC's adjacency matrix convention
  # Undirected edges remain 1 (i — j) by default
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (cpdag_matrix[i, j] == 1 && cpdag_matrix[j, i] == 0) {
        cpdag_matrix[i, j] <- 2    # i → j
        cpdag_matrix[j, i] <- -2   # j ← i
      }
    }
  }
  
  return(cpdag_matrix)
}

#' Convert MIIC-style adjacency matrix to undirected edge list
#'
#' Given an adjacency matrix using MIIC conventions (where entries can be 
#' 1, 2, -2, 6, to encode types of edges), this function extracts 
#' all *unique undirected edges*. Each edge is included once, regardless 
#' of direction or MIIC edge type.
#'
#' @param adj_matrix A square adjacency matrix with named rows and columns,
#'        using MIIC edge type conventions.
#'
#' @return A data frame with columns 'Node1' and 'Node2', listing each edge once

miic_adjacency_to_edges <- function(adj_matrix) {
  # Ensure the matrix has row and column names
  if (is.null(rownames(adj_matrix)) || is.null(colnames(adj_matrix))) {
    stop("Adjacency matrix must have row and column names.")
  }
  
  node_names <- colnames(adj_matrix)
  n_nodes <- length(node_names)
  
  # Initialize list to collect edges
  edge_list <- list()
  
  # Loop over upper triangle only to avoid duplicates
  for (i in 1:(n_nodes - 1)) {
    for (j in (i + 1):n_nodes) {
      value_ij <- adj_matrix[i, j]
      value_ji <- adj_matrix[j, i]
      
      # If any direction has a non-zero value, it's an edge
      if (value_ij != 0 || value_ji != 0) {
        edge_list[[length(edge_list) + 1]] <- c(node_names[i], node_names[j])
      }
    }
  }
  
  # Convert to data frame
  edge_df <- do.call(rbind, edge_list)
  colnames(edge_df) <- c("Node1", "Node2")
  edge_df <- as.data.frame(edge_df, stringsAsFactors = FALSE)
  
  return(edge_df)
}

#' Generates a random covariance matrix from a DAG (in graphNEL format).
#'
#' This function assigns random weights in [0.8, 1.2] to the edges of the DAG and
#' computes the covariance matrix assuming a linear Gaussian SEM:
#'    X = (I - B)^(-1) ε, where B is the weighted adjacency matrix.
#'
#' @param dag A DAG in `graphNEL` format.
#' @return A positive semi-definite covariance matrix corresponding to the DAG structure.
generate_covariance_from_dag <- function(dag) {
  # Extract weighted adjacency matrix (binary at this stage)
  weight_matrix <- pcalg::wgtMatrix(dag)
  
  # Find indices of non-zero (i.e. existing) edges
  non_zero_indices <- which(weight_matrix != 0, arr.ind = TRUE)
  
  # Assign random weights in [0.8, 1.2] to each existing edge
  for (r in seq_len(nrow(non_zero_indices))) {
    i <- non_zero_indices[r, 1]
    j <- non_zero_indices[r, 2]
    weight_matrix[i, j] <- runif(1, 0.8, 1.2)
  }
  
  # Number of variables (nodes in the DAG)
  p <- length(dag@nodes)
  
  # Compute covariance matrix: Σ = (I - B)^(-1)(I - B)^(-T)
  identity_matrix <- diag(p)
  inverse_matrix <- solve(identity_matrix - weight_matrix)
  covariance_matrix <- tcrossprod(inverse_matrix)  # = inverse_matrix %*% t(inverse_matrix)
  
  return(covariance_matrix)
}