# select_replicas.R

set.seed(1234)  # reproducibility
models <- c("Alarm", "Insurance", "Barley", "Mildew")
replicas <- sample(1:50, length(models), replace = TRUE)
selection <- data.frame(model = models, rep_idx = replicas)

# Save the selected replicate indices
dir.create("simulated_data/categorical/bootstrap", recursive = TRUE, showWarnings = FALSE)
write.table(selection, file = "simulated_data/categorical/bootstrap/selected_replicas.txt", sep = "\t", row.names = FALSE, quote = FALSE)