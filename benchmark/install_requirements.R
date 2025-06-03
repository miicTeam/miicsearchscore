# install_requirements.R

# -------------------------
# Install required R packages from requirements.txt
# Used for the "simulations" directory scripts
# -------------------------

# Load required helpers
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")

# Path to requirements file
req_file <- "requirements.txt"

# Read the package list
if (!file.exists(req_file)) {
  stop("❌ Could not find requirements.txt in the current directory.")
}

cat("📦 Reading requirements from", req_file, "\n")
reqs <- read.table(req_file, header = TRUE, stringsAsFactors = FALSE)

# Filter out base packages (they are part of R itself)
base_pkgs <- rownames(installed.packages(priority = "base"))
reqs <- reqs[!reqs$Package %in% base_pkgs, ]

# Install each package
for (i in seq_len(nrow(reqs))) {
  pkg <- reqs$Package[i]
  ver <- reqs$Version[i]
  
  cat("\n➡ Installing", pkg, "version", ver, "...\n")
  
  already_installed <- pkg %in% rownames(installed.packages()) &&
    as.character(packageVersion(pkg)) == ver
  
  if (already_installed) {
    cat("✅", pkg, "already installed at version", ver, "\n")
    next
  }
  
  # Try installing from CRAN
  cran_success <- tryCatch({
    devtools::install_version(pkg, version = ver, repos = "https://cloud.r-project.org")
    TRUE
  }, error = function(e) {
    cat("⚠️ CRAN install failed for", pkg, ":", e$message, "\n")
    FALSE
  })
  
  # If CRAN failed, try Bioconductor
  if (!cran_success) {
    cat("🔄 Trying Bioconductor for", pkg, "...\n")
    tryCatch({
      BiocManager::install(pkg, ask = FALSE, update = FALSE)
    }, error = function(e) {
      cat("❌ Failed to install", pkg, "from Bioconductor:", e$message, "\n")
    })
  }
}

cat("\n✅ Installation process complete.\n")
