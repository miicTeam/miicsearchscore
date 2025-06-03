#' Compute cumulative conditional mutual information gain for a candidate set
#'
#' For a given target variable, this function evaluates the cumulative gain in conditional
#' mutual information (MI) when successively adding variables from `candidates` to an initial
#' conditioning set. Each MI computation is cached using a hash table to improve efficiency.
#'
#' This function supports the greedy selection of local conditioning sets during
#' Step 1 of the MIIC_search&score algorithm for causal graph discovery.
#'
#' @param target The name of the target variable.
#' @param candidates A vector of variable names to be added incrementally to the conditioning set.
#' @param conditioning_set A character vector representing the current conditioning set (possibly empty).
#' @param data A data frame containing all variables (columns) and observations (rows).
#' @param hash_table An environment or named list used to cache mutual information computations.
#'
#' @return A list with:
#'   \describe{
#'     \item{score}{The total(conditional) mutual information gain from adding all candidates.}
#'     \item{hash_table}{The updated cache of mutual information values.}
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

compute_incremental_mi_gain <- function(target, candidates, conditioning_set, data, hash_table) {
  cumulative_gain <- 0  # Initialize total score

  for (candidate in candidates) {
    combined_set <- sort(c(target, candidate))
    # Build a unique key for caching the MI computation
    if (length(conditioning_set) > 0) {
      conditioning_sorted <- sort(conditioning_set)
      key <- digest::digest(c(combined_set, conditioning_sorted))
      if (exists(key, hash_table)) {
        mi_val <- hash_table[[key]]  # Retrieve from cache
      } else {
        # Compute MI with conditioning and cache the result
        mi_val <- miic::computeMutualInfo(data[, target], data[, candidate], df_conditioning = data[, conditioning_set])$infok
        hash_table[[key]] <- mi_val
      }
    } else {
      # Case with no conditioning
      key <- digest::digest(combined_set)
      if (exists(key, hash_table)) {
        mi_val <- hash_table[[key]]
      } else {
        mi_val <- miic::computeMutualInfo(data[, target], data[, candidate])$infok
        hash_table[[key]] <- mi_val
      }
    }

    # Accumulate the score and update the conditioning set
    cumulative_gain <- cumulative_gain + mi_val
    conditioning_set <- c(conditioning_set, candidate)
  }

  return(list(score = cumulative_gain, hash_table = hash_table))
}

#' Greedy search for the optimal local conditioning set maximizing MI gain
#'
#' This function implements a greedy search over subsets of a target node's parents,
#' spouses, and neighbors (Pa ∪ Sp ∪ Ne), aiming to find the set Pa' that maximizes
#' the conditional mutual information with the target.
#'
#' At each step, the candidate set is expanded and scored using incremental
#' mutual information gain. Search stops when no further improvement is possible.
#' This function is used during Step 1 of the MIIC_search&score algorithm.
#'
#' @param target The name of the target node.
#' @param parent_spouse_neighbor_set A character vector of variables adjacent to the target (Pa ∪ Sp ∪ Ne).
#' @param data A data frame of observations (columns = variables).
#' @param hash_table An environment or named list for caching mutual information scores.
#'
#' @return A list with:
#'   \describe{
#'     \item{best_set}{The subset of variables yielding the highest MI gain (Pa').}
#'     \item{hash_table}{The updated mutual information cache.}
#'   }
#'
#' @references
#' Lagrange, N. and Isambert, H. (2025).
#' An efficient search-and-score algorithm for ancestral graphs using multivariate information scores.
#' In \emph{Proceedings of the 42nd International Conference on Machine Learning (ICML 2025)}.
#'
#' @importFrom digest digest
#' @importFrom miic computeMutualInfo
#' @importFrom utils combn
#' @export

search_best_conditioning_set <- function(target, parent_spouse_neighbor_set, data, hash_table) {
  best_sets <- list()         # Store best sets at each level i
  current_set <- c()          # Current conditioning set
  early_stop <- FALSE
  i <- 1
  while (i <= length(parent_spouse_neighbor_set)) {
    # Efficiently handle large combination spaces
    if (i > 1 && (i > 4 || length(parent_spouse_neighbor_set) > 4)) {
      combinations <- matrix(NA, nrow = i, ncol = length(parent_spouse_neighbor_set))
      for (k in seq_along(parent_spouse_neighbor_set)) {
        combinations[, k] <- c(current_set, parent_spouse_neighbor_set[k])
      }
    } else {
      combinations <- combn(parent_spouse_neighbor_set, i)
    }

    scores <- numeric(ncol(combinations))  # MI scores for each combination

    for (j in seq_len(ncol(combinations))) {
      test_set <- unique(combinations[, j])

      if (i > 1) {
        # Decompose into shared, removed, added
        shared <- intersect(current_set, test_set)
        removed  <- setdiff(current_set, shared)
        added  <- setdiff(test_set, shared)

        # Compute MI gain from moving to new set
        res_removed <- compute_incremental_mi_gain(target, removed, shared, data, hash_table)
        res_added  <- compute_incremental_mi_gain(target, added, shared, data, res_removed$hash_table)

        scores[j] <- -res_removed$score + res_added$score
        hash_table <- res_added$hash_table
      } else {
        # i == 1: direct MI evaluation
        key <- digest::digest(sort(c(target, test_set)))
        if (exists(key, hash_table)) {
          mi_val <- hash_table[[key]]
        } else {
          mi_val <- miic::computeMutualInfo(data[, target], data[, test_set])$infok
          hash_table[[key]] <- mi_val
        }
        scores[j] <- mi_val
      }
    }

    # Evaluate best score for this size i
    max_score <- max(scores)
    if (max_score > 0) {
      best_sets[[i]] <- combinations[, which.max(scores)]
      current_set <- best_sets[[i]]
    } else {
      early_stop <- TRUE
      break
    }

    i <- i + 1
  }
  
  # Final best set selection
  final_best <- if (!early_stop && length(best_sets) > 0) {
    best_sets[[length(best_sets)]]
  } else if (early_stop && length(best_sets) > 0) {
    best_sets[[i - 1]]
  } else {
    c()
  }
  
  return(list(best_set = final_best, hash_table = hash_table))
}
