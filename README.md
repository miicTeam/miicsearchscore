# miicsearchscore: An Efficient Search-and-Score Algorithm for Ancestral Graphs using Multivariate Information Scores

This repository provides an R implementation of the **MIIC_search&score** algorithm, introduced in our **ICML 2025** paper, for causal discovery in the presence of latent variables. The algorithm combines a theoretical likelihood decomposition for ancestral graphs with a practical, efficient two-step search-and-score procedure based on multivariate information scores.

## ⚡ Quickstart

```r
# Install devtools if needed
install.packages("devtools")

# Install the package directly
devtools::install_github("miicTeam/miicsearchscore")

# Load the package
library(miicsearchscore)

# Load the example dataset
data(nonlinear_data)

# Run the method on the example data
adj <- run_miic_searchscore(nonlinear_data, n_threads = 1)
```

## 🔍 Overview

The method improves upon MIIC through a greedy scoring scheme based on higher-order ac-connected information subsets. It is especially suited for:

- **Ancestral graphs including latent confounders** (bidirected edges),
- **Complex datasets**, such as continuous including non-linear couplings between variables, or categorical data,
- **Scalable inference**, thanks to localized scoring limited to collider paths of up to two edges.

## 🚀 Installation

You have two ways to install and use the `miicsearchscore` package:

### 🧪 Option 1: Full repository (R package + benchmark)

To access everything (including the benchmark and simulation scripts):

```bash
# Clone the full repository
git clone https://github.com/miicTeam/miicsearchscore.git
cd miicsearchscore
```

Then, open R from this folder and run:

```r
# Install devtools if needed
install.packages("devtools")

# Install from local source
devtools::install(".")
library(miicsearchscore)
```

### ✅ Option 2: Install only the R package

If you only need the core R functions (no benchmark), use:

```r
# Install devtools if needed
install.packages("devtools")

# Install directly from GitHub
devtools::install_github("miicTeam/miicsearchscore")

# Load the package
library(miicsearchscore)
```

> ⚠️ This method installs only the R package — **not** the `benchmark/` folder.

## 🧠 How it works

The algorithm proceeds in two steps:

### Step 0: MIIC inference

```r
miic_result <- miic(data,
                 latent = "orientation",
                 propagation = TRUE,
                 consistent = "orientation",
                 n_threads = n_threads)
summary <- miic_result$summary
summary <- summary[summary$type == "P", ]
hash_table <- new.env()
adj_miic <- miic_result$adj_matrix
```

### Step 1: Node-level pruning and conditioning set selection

```r
step1_result <- apply_node_score_step_1(adj_miic, data, hash_table)
adj_step1_node_score <- step1_result$adj
hash_table <- step1_result$hash_table
```

### Step 2: Edge orientation via mutual information delta optimization

```r
step2_result <- apply_edge_score_step_2(adj_step1_node_score, data, hash_table)
adj_step2_edge_score <- step2_result$adj
```

Or run everything in one call:

```r
adj <- run_miic_searchscore(data, n_threads = 1)
```

## 📁 Repository structure

```
miicsearchscore/
├── R/                         # Core R source files implementing the MIIC_search&score algorithm
├── data/                      # Package dataset (.rda), accessible via data()
├── man/             
├── benchmark/                 # Benchmarking scripts
│   ├── MIIC_search_and_score/ # Scripts to run benchmarks for MIIC_search&score
│   │   ├── categorical/       # Scripts for categorical data settings
│   │   │   ├── bootstrap/    
│   │   │   ├── normal/        
│   │   ├── continuous/       
│   │   │   ├── linear_gaussian/ 
│   │   │   ├── non_linear/    
│   ├── baselines/             # Scripts to run and evaluate baseline methods
│   │   ├── DAGGNN/            
│   │   │   ├── linear_gaussian/ 
│   │   │   ├── non_linear/    
│   │   ├── FCI/               
│   │   │   ├── bootstrap/     
│   │   │   ├── normal/        
│   │   ├── GFCI/             
│   │   ├── M3HC/              
│   ├── data/                 
│   │   ├── CPT/               # Conditional probability tables (used for categorical models)
│   ├── simulations/           # Data and graph generation scripts
│   │   ├── categorical/       
│   │   ├── continuous/        
│   ├── utils/                 # Shared utility scripts: plotting, metrics, graph conversion, etc.
```

## 📊 Benchmarks

Benchmarks for reproducing **Figures 2, 3, E.2, E.3, and Table E.1** of the paper are provided in the `benchmark/` folder. Before running them, **make sure you are in the`benchmark/` directory**.

### 🔧 0. Install required R packages

Before running any simulation, make sure to install the required R packages (with exact versions) using:

```bash
Rscript install_requirements.R
```

This will install all packages listed in requirements.txt, including those from CRAN and Bioconductor.

### 1. Simulate the graph structures: **DAG, CPDAG, and PAG**

You can run both simulations (continuous and categorical) at once with:

```bash
Rscript simulations/run_all_graph.R
```
Or run them separately:

```bash
Rscript simulations/continuous/simulate_dag_cpdag_pag_continuous.R
Rscript simulations/categorical/simulate_dag_cpdag_pag_categorical.R
```

📁 **Output directory**

All output datasets are saved automatically in the `simulated_data/graphs/` directory.

### 🚀 2. Run 🔴 MIIC_search&score and 🔵 MIIC benchmark simulations

You can launch **all benchmark simulations** at once using the main launcher:

```bash
Rscript MIIC_search_and_score/run_all.R
```

This will execute all benchmark pipelines across continuous and categorical scenarios.

⚙️ Alternatively, run each simulation type separately:

#### 🔹 Linear Gaussian simulations

```bash
Rscript MIIC_search_and_score/continuous/linear_gaussian/run_all_linear_gaussian.R
```

#### 🔹 Non-linear simulations

```bash
Rscript MIIC_search_and_score/continuous/non_linear/run_all_non_linear.R
```

#### 🔹 Categorical simulations (normal)

```bash
Rscript MIIC_search_and_score/categorical/normal/run_all_categorical.R
```

#### 🔹 Categorical simulations (bootstrap)

```bash
Rscript MIIC_search_and_score/categorical/bootstrap/run_all_categorical_bootstrap.R
```

📁 **Output directory**

All output graphs are saved automatically in the `results/` directory.

🧠 **Tips**

- If you want to run only a subset of benchmarks, you can edit the `run_all.R` file and comment out specific simulation blocks.
- In each subdirectory of `MIIC_search_and_score` (e.g., `categorical/bootstrap`), you will find additional scripts that generate job submission files for HPC environments using PBS or SLURM. These scripts typically start with `generate_` and `lauch_` and are intended to help launch large-scale benchmark runs efficiently on a cluster.

### 📦 3. (Optional) Generate data for external baseline algorithms

To run other benchmark algorithms (developed in different languages such as **Python** or **MATLAB**), you'll need to generate the corresponding datasets from the simulated graphs.

To generate all types of data at once (continuous, non-linear, categorical, etc.), use:

```bash
Rscript simulations/run_all_data.R
```

You can also launch the data generation scripts individually within each subdirectory, similarly to the graph generation step. For example:

```bash
Rscript simulations/continuous/generate_linear_gaussian_data.R
Rscript simulations/continuous/generate_nonlinear_data.R
Rscript simulations/categorical/generate_categorical_data.R
```

You can edit `run_all_data.R` to comment out lines corresponding to data types you are not interested in.

📁 **Output directory**

All output datasets are saved automatically in the `simulated_data/` directory.

### 🧪 4. (Optional) Run other baseline algorithms

The `baselines/` directory contains benchmarking scripts for external algorithms implemented in Python, MATLAB, and Java. These include:

- 🟢 **DAG-GNN** (Python) — [`4ff8775`](https://github.com/ronikobrosly/DAG_from_GNN/commit/4ff8775f46cc626fad464e53b2002128a02c9a68)
- ⚪️ **FCI** (Python) — [`9689c1b`](https://github.com/py-why/causal-learn/commit/9689c1bdc468847729eacf0921b76f598161ae16)
- 🟣 **GFCI** (Java, via py-tetrad) — [`ea7cefb`](https://github.com/cmu-phil/py-tetrad/commit/ea7cefb12796d26337a0c0f2f7bd4deb470ce523)
- ⚪️ **M3HC** (MATLAB) — [`a829193`](https://github.com/mensxmachina/M3HC/commit/a82919329608d1d6482f476873ec559b4839665e)

For **DAG-GNN** and **FCI**, you will find scripts that launch HPC jobs with automatic data generation on the fly.

For **M3HC** (MATLAB) and **GFCI** (Java), only local execution scripts are provided. These require that the datasets have already been generated in advance (see Section 3).

📁 **Output directory**

All output graphs are saved automatically in the `results/` directory.

### 📈 5. (Optional) Evaluate results and generate benchmark plots

After running the benchmark simulations, you can compute performance metrics (e.g., Precision, Recall, F-score) and generate comparative plots by executing the following script:

```bash
Rscript utils/benchmark_plot.R
```

This script processes the output graph predictions stored in the `results/` directory and produces evaluation figures for each algorithm and setting.

Ensure that all necessary simulation results are present in `results/` before launching this analysis.

📁 **Output directory**

All results are saved automatically in the `results/` directory:

- `results/metrics/`: computed performance metrics (Precision, Recall, F-score)
- `results/plots/`: benchmark figures

### 6. Reproduce Table E.1 – Toy Models Summary

To reproduce the toy model summary table (Table E.1), simply run the following script:

```bash
Rscript utils/toy_model.R
```

## 📄 Citation

If you use this code, please cite:

```bibtex
```

## 👥 Authors

- **Nikita Lagrange** – PhD Student, CNRS, Institut Curie, Sorbonne Université  
  [GitHub](https://github.com/nikitalagrange) • [Website](https://nikitalagrange.github.io)

- **Hervé Isambert** – Research Director, CNRS, Institut Curie, Sorbonne Université  
  [Website](http://kinefold.curie.fr/isambertlab/index.html)

Contributions and feedback are welcome — open an [issue](https://github.com/miicTeam/miicsearchscore/issues) or a [pull request](https://github.com/miicTeam/miicsearchscore/pulls).