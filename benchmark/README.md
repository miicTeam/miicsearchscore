# 📊 Benchmarks

This folder contains the scripts used to reproduce the **Experimental Results** presented in the paper:

- **Figure 2**
- **Figure 3**
- **Figure E.2**
- **Figure E.3**
- **Table E.1**

## 📁 Usage

Before running any benchmark, make sure you are in the `benchmark/` directory:

```bash
cd benchmark/
```

Each script is designed to work relative to this path.

## 🧪 Included Algorithms

Benchmarks are provided for the following causal discovery algorithms:

- 🔵 **MIIC** — supports continuous and categorical data
- 🔴 **MIIC_search&score** — supports continuous and categorical data
- ⚪️ **M3HC** — continuous data only
- 🟣 **GFCI** — continuous data only
- 🟢 **DAG-GNN** — continuous data only
- ⚪️ **FCI** — categorical data only

## 📦 Notes

- Scripts can be executed locally or on a cluster using PBS or SLURM.
- Results are saved in the `results/` subfolder, organized by experiment type and algorithm.
- For detailed explanations of the experimental settings and metrics, refer to the main [README](../README.md#-benchmarks).