library(miic)
library(pcalg)
library(bnlearn)
library(RBGL)

dir_out <- file.path("results", "toy_models")
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)

benchmark_toy_model <- function(adj, X, Y, pa_X, pa_Y, nb_rep, N) {
  idx_df <- 1
  cn <- c("sc_YX", "sc_XY", "sc_latent")
  df_sc <- data.frame(matrix(nrow = 0, ncol = length(cn)))
  colnames(df_sc) <- cn
  
  g <- as(adj, "graphNEL")
  nm_sort <- RBGL::tsort(g)
  adj_sort <- adj[nm_sort, nm_sort]
  g <- as(adj_sort, "graphNEL")
  
  for (n in N) {
    set.seed(0)
    data <- data.frame(rmvDAG(n * nb_rep, g, errDist = "normal"))
    data <- discretize(data, method = "hartemink")
    idx_start <- 1
    idx_end <- n
    sum_df <- 0
    df_sc[idx_df, "sc_YX"] <- 0
    df_sc[idx_df, "sc_XY"] <- 0
    df_sc[idx_df, "sc_latent"] <- 0
    
    for (idx in 1:nb_rep) {
      input_idx <- data[idx_start:idx_end, ]
      sc_YX <- -computeMutualInfo(input_idx[, X], input_idx[, Y], df_conditioning = input_idx[, pa_X])$infok
      sc_XY <- -computeMutualInfo(input_idx[, X], input_idx[, Y], df_conditioning = input_idx[, pa_Y])$infok
      cd <- sort(unique(c(pa_X, pa_Y)))
      sc_latent <- -computeMutualInfo(input_idx[, X], input_idx[, Y], df_conditioning = input_idx[, cd])$infok
      
      sc <- c(sc_YX, sc_XY, sc_latent)
      argmin <- which.min(sc)
      if (min(sc) < 0 & sum(min(sc) == sc) != length(sc)) {
        sum_df <- sum_df + 1
        if (argmin == 1) df_sc[idx_df, "sc_YX"] <- df_sc[idx_df, "sc_YX"] + 1
        if (argmin == 2) df_sc[idx_df, "sc_XY"] <- df_sc[idx_df, "sc_XY"] + 1
        if (argmin == 3) df_sc[idx_df, "sc_latent"] <- df_sc[idx_df, "sc_latent"] + 1
      }
      
      idx_start <- idx_start + n
      idx_end <- idx_end + n
    }
    
    df_sc[idx_df, ] <- (df_sc[idx_df, ] / sum_df) * 100
    idx_df <- idx_df + 1
  }
  
  return(df_sc)
}

# --- TOY MODELS ---

nb_rep <- 50
N <- c(1000, 5000, 10000, 20000, 35000, 50000)

# Model 1
nm <- c("X1", "X2", "X3", "X4", "X5", "X6")
adj <- matrix(0, ncol = 6, nrow = 6, dimnames = list(nm, nm))
adj["X1", "X2"] <- 1; adj["X3", "X2"] <- 1; adj["X3", "X4"] <- 1
adj["X5", "X4"] <- 1; adj["X6", "X4"] <- 1
tm_1 <- benchmark_toy_model(adj, "X2", "X4", c("X1"), c("X5", "X6"), nb_rep, N)
write.csv(tm_1, file = file.path(dir_out, "toy_model_1.csv"), row.names = FALSE)

# Model 2
adj <- matrix(0, ncol = 6, nrow = 6, dimnames = list(nm, nm))
adj["X1", "X2"] <- 1; adj["X3", "X2"] <- 1; adj["X3", "X4"] <- 1
adj["X5", "X4"] <- 1; adj["X5", "X2"] <- 1; adj["X6", "X4"] <- 1
tm_2 <- benchmark_toy_model(adj, "X2", "X4", c("X1", "X5"), c("X5", "X6"), nb_rep, N)
write.csv(tm_2, file = file.path(dir_out, "toy_model_2.csv"), row.names = FALSE)

# Model 3
nm <- c("X1", "X2", "X3", "X4", "X5", "X6", "X7", "X8")
adj <- matrix(0, ncol = 8, nrow = 8, dimnames = list(nm, nm))
adj["X1", "X2"] <- 1; adj["X3", "X2"] <- 1; adj["X3", "X4"] <- 1
adj["X5", "X4"] <- 1; adj["X7", "X6"] <- 1
adj["X8", "X4"] <- 1; adj["X8", "X6"] <- 1

tm_3_1 <- benchmark_toy_model(adj, "X2", "X4", c("X1"), c("X5", "X6"), nb_rep, N)
tm_3_2 <- benchmark_toy_model(adj, "X4", "X6", c("X5", "X2"), c("X7"), nb_rep, N)
write.csv(tm_3_1, file = file.path(dir_out, "toy_model_3_1.csv"), row.names = FALSE)
write.csv(tm_3_2, file = file.path(dir_out, "toy_model_3_2.csv"), row.names = FALSE)
