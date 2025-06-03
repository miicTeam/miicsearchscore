# select_replicas.R

set.seed(1234)  # reproducibility
models <- c("Alarm", "Insurance", "Barley", "Mildew")
replicas <- sample(1:50, length(models), replace = TRUE)
selection <- data.frame(model = models, rep_id = replicas)

# Save the selected replicate indices
write.table(selection, file = "selected_replicas.txt", sep = "\t", row.names = FALSE, quote = FALSE)