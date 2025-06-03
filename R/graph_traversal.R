#' Retrieve all directed ancestors of each node in a causal graph
#'
#' For each node, this function performs a backward traversal along directed edges (i.e., parent relationships),
#' collecting all nodes that have a directed path (→) to the target node.
#' It is designed for MIIC-style adjacency matrices used in partially oriented graphs (e.g., PAGs),
#' where only directed edges (2 = i → j) are followed. 
#'
#' This function is typically used during edge orientation to identify ancestral constraints.
#'
#' @param adj A square adjacency matrix in MIIC format:
#'   0 = no edge, 1 = undirected, 2 = i → j, -2 = j → i, 6 = i ↔ j.
#'
#' @return A named list where each entry is a character vector
#'   containing the nodes that are directed ancestors of the corresponding variable.
#'
#' @references
#' Lagrange, N. and Isambert, H. (2025).
#' An efficient search-and-score algorithm for ancestral graphs using multivariate information scores.
#' In \emph{Proceedings of the 42nd International Conference on Machine Learning (ICML 2025)}.
#'
#' @importFrom container deque ref_add ref_popleft
#' @export

find_all_ancestors <- function(adj) {
  if (is.null(colnames(adj))) stop("Adjacency matrix must have named columns.")
  node_names <- colnames(adj)
  ancestors_list <- list()
  
  for (target_node in node_names) {
    # Get direct parents of the target_node (edges j → target_node)
    direct_parents <- names(which(adj[, target_node] == 2))
    
    if (length(direct_parents) > 0) {
      queue <- container::deque()
      visited <- c(target_node)
      container::ref_add(queue, target_node)
      
      while (length(queue) != 0) {
        current_node <- container::ref_popleft(queue)
        
        # Explore directed incoming edges: j → current_node
        incoming_parents <- names(which(adj[, current_node] == 2))
        
        for (source_node in incoming_parents) {
          if (!(source_node %in% visited)) {
            visited <- c(visited, source_node)
            container::ref_add(queue, source_node)
            
            if (target_node %in% names(ancestors_list)) {
              ancestors_list[[target_node]] <- c(ancestors_list[[target_node]], source_node)
            } else {
              ancestors_list[[target_node]] <- c(source_node)
            }
          }
        }
      }
    }
  }
  
  return(ancestors_list)
}
