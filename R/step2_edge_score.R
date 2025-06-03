#' Convert MIIC-style adjacency matrix to undirected edge list
#'
#' Converts a square adjacency matrix—using MIIC-style encoding of edge types (2 = parent, -2 = child, 6 = bidirected, 1 = undirected)—into
#' a list of undirected edges. Each edge is returned only once, regardless of direction.
#' This function is typically used to initialize the set of candidate edges for orientation refinement.
#'
#' @param adj_matrix A square adjacency matrix with row and column names,
#'        using MIIC edge type conventions.
#'
#' @return A data frame with two columns:
#'   \describe{
#'     \item{Node1}{The name of the first node.}
#'     \item{Node2}{The name of the second node.}
#'   }
#'
#' @seealso [compute_edge_deltas()], [apply_edge_score_step_2()]
#' @noRd

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

#' Greedy edge orientation (Step 2 of MIIC_search&score)
#'
#' This function implements **Step 2** of the MIIC_search&score algorithm: a greedy local search
#' over the current adjacency matrix to optimize edge orientations based on conditional mutual information scores.
#' At each iteration, the best edge operation \eqn{(X, Y) \rightarrow op} with \eqn{\Delta(X, Y) < 0}
#' is selected and applied.
#'
#' The process stops when no more improving move exists or when the graph structure stabilizes
#' (i.e., no change across iterations).
#'
#' ## Tabu memory
#' A short-term memory is used to store recent operations and avoid oscillations
#' (repetitive flipping of the same edges).
#'
#' @param adj A square adjacency matrix (MIIC-style) with entries in \{2, -2, 6, 1, 0\}.
#' @param data A data frame of observed variables (columns) and samples (rows).
#' @param hash_table An environment or named list used to cache mutual information computations.
#'
#' @return A list with:
#'   \describe{
#'     \item{adj}{The updated adjacency matrix after greedy edge reorientation.}
#'     \item{hash_table}{The updated hash table of mutual information values.}
#'   }
#'
#' @references
#' Lagrange, N. and Isambert, H. (2025).
#' An efficient search-and-score algorithm for ancestral graphs using multivariate information scores.
#' In \emph{Proceedings of the 42nd International Conference on Machine Learning (ICML 2025)}.
#'
#' @seealso [compute_edge_deltas()]
#' @importFrom utils tail
#' @export

apply_edge_score_step_2 <- function(adj, data, hash_table) {
  # Initializations
  adj_previous <- matrix(0, nrow = ncol(adj), ncol = ncol(adj))
  variable_names <- colnames(adj)
  colnames(adj_previous) <- rownames(adj_previous) <- variable_names
  num_nodes <- ncol(adj)

  adjacency_history <- list()
  adjacency_history[[1]] <- adj
  
  iteration_count <- 0
  history_index <- 1
  
  # Tabu list to prevent undoing recent operations
  tabu_list <- data.frame(X = character(), Y = character(), op = integer(), stringsAsFactors = FALSE)
  tabu_index <- 1
  
  # Initial edge set
  edge_list <- miic_adjacency_to_edges(adj)
  
  while (!identical(adj_previous, adj)) {
    adj_previous <- adj
    iteration_count <- iteration_count + 1
    history_index <- history_index + 1
    
    # First iteration: compute all deltas
    if (history_index == 2) {
      delta_result <- compute_edge_deltas(edge_list, adj, data, hash_table)
      delta_table <- delta_result$edge_deltas
      hash_table <- delta_result$hash_table
    } else {
      # Stop if matrix already seen
      for (past_matrix in adjacency_history) {
        if (isTRUE(all.equal(adj, past_matrix))) {
          return(list(adj = adj, hash_table = hash_table))
        }
      }
    }
    
    adjacency_history[[history_index]] <- adj
    
    # Sort deltas: keep only improving ones
    improving_deltas <- delta_table[delta_table$delta < 0, ]
    sorted_deltas <- improving_deltas[order(improving_deltas$delta), ]
    
    delta_index <- 1
    while (delta_index <= nrow(sorted_deltas)) {
      X <- sorted_deltas[delta_index, "X"]
      Y <- sorted_deltas[delta_index, "Y"]
      best_op <- sorted_deltas[delta_index, "op"]
      # Apply candidate reorientation
      test_matrix <- adj
      if (best_op == 1) {
        test_matrix[Y, X] <- 2
        test_matrix[X, Y] <- -2
      } else if (best_op == 2) {
        test_matrix[Y, X] <- -2
        test_matrix[X, Y] <- 2
      } else if (best_op == 3) {
        test_matrix[Y, X] <- 6
        test_matrix[X, Y] <- 6
      }
      
      # Skip if already seen
      already_encountered <- any(sapply(adjacency_history, function(m) isTRUE(all.equal(test_matrix, m))))
      if (already_encountered) {
        adj <- test_matrix
        delta_index <- delta_index + 1
        next
      }
      
      # Avoid recent forbidden operations
      recent_tabu <- if (nrow(tabu_list) >= 1) tail(tabu_list, 1) else tabu_list
      is_forbidden <- any(recent_tabu$X == X & recent_tabu$Y == Y & recent_tabu$op == best_op)
      
      if (!is_forbidden) {
        # Accept reorientation
        delta_result <- compute_edge_deltas(edge_list, test_matrix, data, hash_table)
        delta_table <- delta_result$edge_deltas
        hash_table <- delta_result$hash_table
        
        tabu_list[tabu_index, ] <- list(X = X, Y = Y, op = best_op)
        tabu_index <- tabu_index + 1
        
        adj <- test_matrix
        break  # Restart from updated structure
      } else {
        delta_index <- delta_index + 1
      }
    }
  }
  
  return(list(adj = adj, hash_table = hash_table))
}