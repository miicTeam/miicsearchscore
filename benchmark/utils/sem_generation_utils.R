# ==============================================================================
# File        : sem_generation_utils.R
# Description : Helper functions for generating synthetic node distributions
#               in Structural Equation Models (SEM), both linear and non-linear.
#
# Author      : Vincent Cabeli
# Co-Author   : Louise Dupuis
# Maintainer  : Nikita Lagrange
# Created on  : 2023
# Version     : Refactored 2025-05-07
#
# License     : GPL (>= 3)
# ==============================================================================

# Load required libraries
library(quantmod)
library(infotheo)
library(data.table)

# Generate a mixture of distributions given a label vector
generate_mixture <- function(n, distributions, labels = NULL) {
  if (is.null(labels)) {
    labels <- sample(1:length(distributions), size = n, replace = TRUE)
  }
  output <- numeric(n)
  for (i in seq_along(distributions)) {
    output[labels == i] <- distributions[[i]][labels == i]
  }
  return(output)
}

# Rescale values to a target [min, max] interval
rescale_values <- function(x, min = 0, max = 1) {
  if (is.null(ncol(x))) {
    scaled <- (x - min(x)) / (max(x) - min(x))
  } else {
    scaled <- x
    for (i in 1:ncol(x)) {
      scaled[, i] <- (x[, i] - min(x[, i])) / (max(x[, i]) - min(x[, i]))
    }
  }
  return(scaled * (max - min) + min)
}

# Discretize a continuous distribution using valley detection and fallback heuristics
discretize_node <- function(x) {
  dens <- density(x)
  valleys <- dens$x[findValleys(dens$y)]
  
  if (length(valleys) > 0 && length(valleys) < 15) {
    levels <- cut(x, breaks = c(min(x), valleys, max(x)), labels = FALSE, include.lowest = TRUE)
    uninformative <- sapply(unique(levels), function(lvl) {
      bin <- x[levels == lvl]
      length(bin) > 0.9 * length(x) && sd(bin) > 0.05
    })
    if (any(uninformative)) {
      lvl <- which(uninformative)
      new_levels <- discretize(x[levels == lvl], disc = "equalwidth", nbins = max(1, floor(log(length(x)) - 2)))[, 1]
      levels[levels == lvl] <- new_levels + lvl - 1
    }
    levels <- factor(levels)
    levels(levels) <- seq_along(levels(levels))
  } else {
    levels <- discretize(x, disc = "equalwidth", nbins = max(1, floor(log(length(x)))))[, 1]
  }
  
  if (median(table(levels)) < length(x) / 100) {
    levels <- discretize(x, disc = "equalwidth", nbins = max(1, floor(log(length(x)))))[, 1]
  }
  return(factor(levels))
}

# Generate a linear Gaussian SEM output
linear_sem <- function(parents_df) {
  n <- nrow(parents_df)
  p <- ncol(parents_df)
  coefs <- sapply(1:p, function(i) if (runif(1) > 0.5) runif(1, -2, -0.1) else runif(1, 0.1, 2))
  noise <- matrix(rnorm(n * p), ncol = p)
  alpha <- matrix(rep(runif(p, 2, 4), each = n), ncol = p)
  scale <- matrix(rep(runif(p, 0.1, 0.5), each = n), ncol = p)
  noisy_input <- coefs * parents_df + sign(noise) * abs(noise)^alpha * scale
  return(rowSums(noisy_input))
}

# Draw numerical values for factor levels (randomized encoding)
encode_discrete_values <- function(factor_vec) {
  n_levels <- nlevels(factor_vec)
  step <- 1 / (n_levels + 1)
  values <- seq(step, 1 - step, by = step) + rnorm(n_levels, 0, step / 5)
  values <- sample(values)
  return(values[as.numeric(factor_vec)])
}

# Generate a child node distribution from discrete parent configurations
distribution_from_discrete <- function(parent_df, n_bins) {
  parent_df <- data.table(parent_df)
  global_weights <- runif(n_bins)
  global_weights <- global_weights / sum(global_weights)
  unique_combinations <- unique(parent_df)
  prob_table <- matrix(nrow = nrow(unique_combinations), ncol = n_bins)
  for (j in 1:n_bins) {
    weights <- c(sort(runif(nrow(unique_combinations) - 1)), 1) * global_weights[j]
    prob_table[, j] <- weights - c(0, head(weights, -1))
  }
  prob_table <- prob_table / rowSums(prob_table)
  prob_list <- setNames(split(prob_table, row(prob_table)), apply(unique_combinations, 1, paste, collapse = "-"))
  parent_df[, key := do.call(paste, c(.SD, sep = "-"))]
  parent_df[, child := sapply(key, function(k) sample(1:n_bins, 1, prob = prob_list[[k]]))]
  return(as.factor(parent_df$child))
}

# Apply a random nonlinear transformation to a distribution
nonlinear_transform <- function(x) {
  transform <- sample(c("exp", "sin", "cos"), 1)
  return(do.call(transform, list(x)))
}

# Generate a child node distribution from mixed parent types using a nonlinear SEM
nonlinear_sem <- function(parents_df, discrete_indices) {
  n <- nrow(parents_df)
  p <- ncol(parents_df)
  continuous_indices <- setdiff(1:p, discrete_indices)
  cross_terms <- choose(length(continuous_indices), 2)
  all_features <- parents_df
  
  # Add interaction terms
  if (cross_terms > 0) {
    for (i in 1:(length(continuous_indices) - 1)) {
      for (j in (i + 1):length(continuous_indices)) {
        cross <- rescale_values(parents_df[, continuous_indices[i]], -1, 1) *
          rescale_values(parents_df[, continuous_indices[j]], -1, 1)
        all_features <- cbind(all_features, cross)
      }
    }
  }
  
  # Rescale and apply exponents
  poly_indices <- setdiff(1:ncol(all_features), discrete_indices)
  for (idx in poly_indices) {
    all_features[, idx] <- rescale_values(all_features[, idx], -1, 1)
  }
  
  exponents <- sample(1:3, size = length(poly_indices), replace = TRUE)
  for (i in poly_indices) {
    all_features[, i] <- all_features[, i]^exponents[i]
  }
  
  noise <- matrix(rnorm(n * ncol(all_features)), ncol = ncol(all_features))
  output <- rowSums(all_features * 1 + noise * (0.1 / length(poly_indices) / exponents))
  return(rescale_values(nonlinear_transform(output)))
}

# Generate a node distribution depending on parent types and target discretization
generate_child_distribution <- function(node, parents, parent_df, node_discrete, is_discrete_vec, method = "nonlinear") {
  all_discrete <- all(is_discrete_vec[parents])
  
  if (all_discrete) {
    bins <- sample(2:4, 1)
    dist <- distribution_from_discrete(parent_df, bins)
  } else if (node_discrete) {
    for (col in setdiff(parents, names(is_discrete_vec)[is_discrete_vec])) {
      parent_df[[col]] <- discretize_node(parent_df[[col]])
    }
    bins <- sample(2:4, 1)
    dist <- distribution_from_discrete(parent_df, bins)
  } else if (method == "nonlinear") {
    discrete_ids <- which(is_discrete_vec[parents])
    dist <- nonlinear_sem(parent_df, discrete_ids)
  } else {
    dist <- rescale_values(linear_sem(parent_df))
  }
  return(dist)
}
