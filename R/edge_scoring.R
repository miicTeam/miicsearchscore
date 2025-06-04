# Extract local structure around X and Y (parents, children, spouses)
get_nodes <- function(adj_mat, node, codes, exclude) {
  setdiff(colnames(adj_mat)[adj_mat[, node] %in% codes], exclude)
}

#' Compute delta scores for edge orientation
#'
#' This function implements **Step 2** of the MIIC_search&score algorithm.
#' For each edge (X, Y), it evaluates whether reorienting the edge improves the global score,
#' based on a decomposition of the log-likelihood into local mutual information contributions.
#'
#' ## Delta score definition
#' For each edge, three scores are computed based on conditional mutual information:
#' \itemize{
#'   \item \code{X <- Y} (op = 1): \eqn{-I(Y ; X | Pa'_X)}
#'   \item \code{X -> Y} (op = 2): \eqn{-I(X ; Y | Pa'_Y)}
#'   \item \code{X <-> Y} (op = 3): \eqn{-I(X ; Y | Pa'_X ∪ Pa'_Y)}
#' }
#' where \eqn{Pa'_X = Pa(X) \ Y} and \eqn{Pa'_Y = Pa(Y) \ X}.
#'
#' The delta score is defined as:
#' \deqn{\delta = \min(score_{YX}, score_{XY}, score_{latent}) - score_{current}}
#' If all scores are equal, no change is suggested (\code{delta = 0}, \code{op = 0}).
#'
#' ## Acyclicity constraint
#' Reorientations that would introduce cycles are automatically blocked by checking
#' ancestor relationships: if \eqn{X \in Anc(Y)}, then \eqn{Y \rightarrow X} is forbidden, and vice versa.
#'
#' @param edge_list A data frame with two columns 'Node1' and 'Node2', specifying candidate edges to reorient.
#' @param adj A square adjacency matrix using MIIC conventions:
#'   \itemize{
#'     \item 2 = parent
#'     \item -2 = child
#'     \item 6 = bidirected
#'     \item 1 = undirected
#'     \item 0 = no edge
#'   }
#' @param data A data frame containing the observed variables (columns) and samples (rows).
#' @param hash_table An environment or named list used to cache conditional mutual information values.
#'
#' @return A list with:
#'   \describe{
#'     \item{edge_deltas}{A data frame with columns 'X', 'Y', 'delta', and 'op', where \code{op} indicates the optimal orientation:
#'     0 = no change, 1 = X <- Y, 2 = X -> Y, 3 = X <-> Y.}
#'     \item{hash_table}{The updated cache of mutual information computations.}
#'   }
#'
#' @references
#' Lagrange, N. and Isambert, H. (2025).
#' An efficient search-and-score algorithm for ancestral graphs using multivariate information scores.
#' In \emph{Proceedings of the 42nd International Conference on Machine Learning (ICML 2025)}.
#'
#' @importFrom digest digest
#' @importFrom miic computeMutualInfo
#' @export

compute_edge_deltas <- function(edge_list, adj, data, hash_table) {
  edge_deltas <- data.frame(
    X = character(), Y = character(),
    delta = numeric(), op = integer(),
    stringsAsFactors = FALSE
  )
  
  orientation_code <- c(-2, 2, 6)  # Orientations: -2 (X <- Y), 2 (X -> Y), 6 (X <-> Y)
  for (i in seq_len(nrow(edge_list))) {
    X <- edge_list[i, "Node1"]
    Y <- edge_list[i, "Node2"]
    current_type <- adj[X, Y]
    
    pa_X  <- get_nodes(adj, X, c(2, 6), Y)
    pa_Y  <- get_nodes(adj, Y, c(2, 6), X)
    pa_X_direct <- get_nodes(adj, X, 2, Y)
    pa_Y_direct <- get_nodes(adj, Y, 2, X)
    ch_X  <- get_nodes(adj, X, -2, Y)
    ch_Y  <- get_nodes(adj, Y, -2, X)
    sp_X  <- get_nodes(adj, X, 6, Y)
    sp_Y  <- get_nodes(adj, Y, 6, X)

    # === Skip scoring if both nodes have no parents ===
    if (length(pa_X) == 0 && length(pa_Y) == 0) {
      edge_deltas[nrow(edge_deltas) + 1, ] <- list(X, Y, 0, 0)
      next
    }
    
    # === Block orientations that would introduce cycles ===
    blocked <- c(0, 0, 0)  # [X <- Y, X -> Y, X <-> Y]
    adj_test <- adj
    adj_test[X, Y] <- 1
    adj_test[Y, X] <- 1
    # Precompute ancestors of each node for acyclicity checks
    ancestors <- find_all_ancestors(adj_test)
    ac_X <- ancestors[[X]]
    ac_Y <- ancestors[[Y]]

    # Acyclicity constraints
    if (X %in% ac_Y) blocked[c(1, 3)] <- 1  # X ∈ Anc(Y) ⇒ forbid Y → X &  Y ↔ X
    if (Y %in% ac_X) blocked[c(2, 3)] <- 1  # Y ∈ Anc(X) ⇒ forbid X → Y & X ↔ Y

    # Local V-structure constraints
    if (any(ch_X %in% pa_Y_direct)) blocked[c(1, 3)] <- 1
    if (any(ch_X %in% sp_Y)) blocked[1] <- 1
    if (any(sp_X %in% pa_Y_direct)) blocked[1] <- 1
    if (any(pa_X_direct %in% ch_Y)) blocked[c(2, 3)] <- 1
    if (any(sp_X %in% ch_Y)) blocked[2] <- 1
    if (any(pa_X_direct %in% sp_Y)) blocked[2] <- 1
    
    # Never block the current edge type (it must always be scored)
    blocked[which(orientation_code == current_type)] <- 0
    
    # === Score each possible orientation ===
    compute_mi <- function(x, y, conditioning) {
      key <- digest::digest(c(sort(c(x, y)), sort(conditioning)))
      if (!exists(key, hash_table)) {
        mi <- miic::computeMutualInfo(data[, x], data[, y], df_conditioning = data[, conditioning])$infok
        hash_table[[key]] <- mi
      }
      -hash_table[[key]]
    }
    
    # X <- Y
    score_YX <- if (!blocked[1]) {
      if (length(pa_X)) compute_mi(Y, X, pa_X) else 0
    } else 0
    # X -> Y
    score_XY <- if (!blocked[2]) {
      if (length(pa_Y)) compute_mi(X, Y, pa_Y) else 0
    } else 0
    # X <-> Y
    score_latent <- if (!blocked[3]) {
      pa_union <- unique(c(pa_X, pa_Y))
      if (length(pa_union)) compute_mi(X, Y, pa_union) else 0
    } else 0
    if(length(pa_X) == 0||length(pa_Y) == 0){
      score_latent <- 0
    }
    
    candidate_scores <- c(score_YX, score_XY, score_latent)
    
    # === Determine optimal operation and compute delta ===
    if (length(unique(candidate_scores)) == 1) {
      op <- 0  # No change suggested
      delta <- 0
    } else {
      op <- which.min(candidate_scores)
      best_score <- candidate_scores[op]
      
      # === Score of current edge orientation ===
      baseline_score <- switch(
        as.character(current_type),
        "1"  = 0,
        "2"  = if (length(pa_Y) == 0) -miic::computeMutualInfo(data[, X], data[, Y])$infok else score_XY,
        "-2" = if (length(pa_X) == 0) -miic::computeMutualInfo(data[, X], data[, Y])$infok else score_YX,
        "6"  = if (length(c(pa_X, pa_Y)) == 0) -miic::computeMutualInfo(data[, X], data[, Y])$infok else score_latent
      )

      delta <- best_score - baseline_score
      if (is.nan(delta)) delta <- 0
    }
    
    # Save result
    edge_deltas[nrow(edge_deltas) + 1, ] <- list(X, Y, delta, op)
  }
  
  return(list(edge_deltas = edge_deltas, hash_table = hash_table))
}