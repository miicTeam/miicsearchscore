library(dplyr)
library(ggplot2)
library(reshape2)
library(stringr)
library(hrbrthemes)
library(ggpubr)
library(RColorBrewer)

# Compute truncated confidence intervals in [0,1]
conf_int <- function(data, nb_rep) {
  mc <- rowMeans(data, na.rm = TRUE)
  se <- apply(data, 1, sd, na.rm = TRUE) / sqrt(nb_rep)
  t_score <- qt(p = 0.025, df = nb_rep - 1, lower.tail = FALSE)
  margin <- t_score * se
  lower <- pmax(0, mc - margin)
  upper <- pmin(1, mc + margin)
  rbind(lower, upper)
}

# Plot precision and recall with confidence intervals
plot_metrics <- function(result, N, legend, path, nb_rep, algo_colors) {
  cleaned_legend <- str_replace(legend, "_\\d+L$", "")
  
  metrics <- list(Precision = result$pre, Recall = result$rec, Fscore = result$fscore)
  N_log <- log10(as.numeric(N))
  nb_N <- length(N_log)
  nb_params <- length(legend)
  total_rows <- nb_N * nb_params
  
  build_df <- function(metric_matrix) {
    values <- ci_low <- ci_up <- rep(NA, total_rows)
    parameters_raw <- rep(legend, each = nb_N)
    parameters_clean <- str_replace(parameters_raw, "_\\d+L$", "")
    n_vals <- rep(N_log, nb_params)
    
    for (i in seq_along(legend)) {
      name <- legend[i]
      cols <- paste0(name, "_", 1:nb_rep)
      cols_exist <- cols[cols %in% colnames(metric_matrix)]
      if (length(cols_exist) == 0) next
      
      metric_subset <- metric_matrix[, cols_exist, drop = FALSE]
      idx <- ((i - 1) * nb_N + 1):(i * nb_N)
      
      values[idx] <- rowMeans(metric_subset, na.rm = TRUE)
      
      if (ncol(metric_subset) > 1) {
        ci <- conf_int(metric_subset, ncol(metric_subset))
        ci_low[idx] <- ci[1, ]
        ci_up[idx] <- ci[2, ]
      } else {
        ci_low[idx] <- values[idx]
        ci_up[idx] <- values[idx]
      }
    }
    
    data.frame(
      Value = values,
      N = n_vals,
      Parameter = factor(parameters_clean, levels = unique(parameters_clean)),
      ci_lower = ci_low,
      ci_upper = ci_up
    )
  }
  
  df_list <- lapply(metrics, build_df)
  names(df_list) <- names(metrics)
  
  plot_metric <- function(df, metric_name) {
    ggplot(df, aes(x = N, y = Value, group = Parameter)) +
      geom_line(aes(color = Parameter), size = 1.2, na.rm = TRUE) +
      geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper, fill = Parameter), alpha = 0.3, na.rm = TRUE) +
      theme_classic() +
      theme(
        axis.text = element_blank(), axis.title = element_blank(),
        axis.line = element_line(linewidth = .7),
        axis.ticks = element_line(linewidth = .9),
        axis.ticks.length = unit(.25, "cm"),
        legend.position = "none"
      ) +
      scale_x_continuous(breaks = scales::pretty_breaks(n = 3)) +
      scale_color_manual(values = algo_colors) +
      scale_fill_manual(values = algo_colors) +
      ylim(0, 1)
  }
  
  f_precision <- plot_metric(df_list$Precision, "Precision")
  f_recall <- plot_metric(df_list$Recall, "Recall")
  
  combined_plot <- ggarrange(f_precision, f_recall, ncol = 2, nrow = 1, common.legend = FALSE, legend = "none")
  ggsave(filename = path, plot = combined_plot, limitsize = FALSE, width = 7, height = 6)
}

