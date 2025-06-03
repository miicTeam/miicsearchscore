#' Node-level conditioning set selection and edge pruning (Step 1 of MIIC_search&score)
#'
#' Implements Step 1 of the MIIC_search&score algorithm for ancestral graphs.
#' At each node, the function evaluates local conditioning sets among connected nodes
#' (parents, spouses, and neighbors) using multivariate information scores.
#' Edges that do not significantly contribute to the node-level score
#' are marked as non-informative and removed.
#'
#' The process iterates over all nodes and continues until convergence, i.e., when the
#' adjacency matrix no longer changes between two consecutive iterations.
#'
#' This step corresponds to the first phase of the search-and-score algorithm,
#' which aims at minimizing local contributions to the likelihood score
#' of each node with respect to its ac-connected neighborhood.
#'
#' @param adj A square adjacency matrix in MIIC format:
#'   0 = no edge, 1 = undirected, 2/-2 = directed, 6 = bidirected.
#' @param data A data.frame of observations. Each column corresponds to a variable.
#' @param hash_table An environment (created with \code{new.env()}) used to cache
#'   previously computed (conditional) mutual information scores.
#'
#' @return A list with the following elements:
#' \describe{
#'   \item{adj}{The updated adjacency matrix after node score minimization and edge pruning.}
#'   \item{hash_table}{The updated environment containing cached information values.}
#' }
#'
#' @references
#' Lagrange, N. and Isambert, H. (2025).
#' An efficient search-and-score algorithm for ancestral graphs using multivariate information scores.
#' In \emph{Proceedings of the 42nd International Conference on Machine Learning (ICML 2025)}.
#' @seealso [search_best_conditioning_set()], [find_all_ancestors()]
#' @export
#' 
apply_node_score_step_1 <- function(adj, data, hash_table) {
  if (is.null(colnames(adj))) stop("Adjacency matrix must have named columns.")
  num_nodes <- ncol(adj)
  node_names <- colnames(adj)

  adj_previous <- matrix(0, num_nodes, num_nodes)

  while (!identical(adj_previous, adj)) {
    adj_previous <- adj
    flag_matrix <- adj
    
    for (target_node in node_names) {
      # Get candidate neighbors (directed, undirected, or bidirected)
      parent_spouse_neighbor_set <- node_names[which(adj[, target_node] %in% c(1, 2, 6))]
      
      if (length(parent_spouse_neighbor_set) > 0) {
        # Run step 1 scoring for best conditioning set
        scoring_result <- search_best_conditioning_set(target_node, parent_spouse_neighbor_set, data, hash_table)
        best_set <- scoring_result[["best_set"]]
        hash_table <- scoring_result[["hash_table"]]
        
        # Identify neighbors to remove
        to_remove <- setdiff(parent_spouse_neighbor_set, best_set)
        for (neighbor in to_remove) {
          if (flag_matrix[target_node, neighbor] != 0) {
            if (flag_matrix[neighbor, target_node] != 7 && flag_matrix[target_node, neighbor] != 7) {
              flag_matrix[neighbor, target_node] <- 7
              flag_matrix[target_node, neighbor] <- 1
            } else {
              flag_matrix[neighbor, target_node] <- 7
              flag_matrix[target_node, neighbor] <- 7
            }
          }
        }
      }
    }
    
    # Update adjacency matrix based on orientation flags
    for (i in seq_len(num_nodes)) {
      for (j in seq_len(i - 1)) {
        if (flag_matrix[j, i] == 7 && flag_matrix[i, j] != 7) {
          adj[j, i] <- 1
          adj[i, j] <- 1
        } else if (flag_matrix[i, j] == 7 && flag_matrix[j, i] != 7) {
          adj[i, j] <- 1
          adj[j, i] <- 1
        } else if (flag_matrix[i, j] != 7 && flag_matrix[j, i] != 7) {
          adj[i, j] <- flag_matrix[i, j]
          adj[j, i] <- flag_matrix[j, i]
        }
      }
    }
  }
  
  # Final clean-up: remove or orient remaining ambiguous edges
  for (i in seq_len(num_nodes)) {
    for (j in seq_len(i - 1)) {
      if (flag_matrix[i, j] == 7 && flag_matrix[j, i] == 7) {
        adj[i, j] <- 0
        adj[j, i] <- 0
      } else if (flag_matrix[i, j] == 7 && flag_matrix[j, i] != 7) {
        adj[i, j] <- -2
        adj[j, i] <- 2
      } else if (flag_matrix[j, i] == 7 && flag_matrix[i, j] != 7) {
        adj[i, j] <- 2
        adj[j, i] <- -2
      }
    }
  }
  
  # Resolve remaining undirected edges using acyclic orientation
  undirected_counts <- lapply(node_names, function(node) length(which(adj[, node] == 1)))
  names(undirected_counts) <- node_names
  undirected_counts <- sort(unlist(undirected_counts), decreasing = TRUE)

  for (node in names(undirected_counts)) {
    if (undirected_counts[[node]] > 0) {
      undirected_neighbors <- names(which(adj[, node] == 1))
      for (neighbor in undirected_neighbors) {
        ancestors_map <- find_all_ancestors(adj)
        if (!(node %in% ancestors_map[[neighbor]])) {
          adj[node, neighbor] <- -2
          adj[neighbor, node] <- 2
        } else if (!(neighbor %in% ancestors_map[[node]])) {
          adj[node, neighbor] <- 2
          adj[neighbor, node] <- -2
        }
      }
    }
  }
  return(list(adj = adj, hash_table = hash_table))
}