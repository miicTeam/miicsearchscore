# M3HC Benchmark

This repository contains the MATLAB script `M3HC_eval.m`, which benchmarks the M3HC algorithm on simulated datasets.
## 📄 Script Information

- **File**: `baselines/M3HC/M3HC_eval.m`
- **Description**: Benchmarking of M3HC on simulated linear and non-linear datasets, under varying sample sizes, graph densities, and hidden variable conditions.
- **Author**: Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
- **Created on**: 2025-05-27
- **Version**: 1.0.0
- **License**: GPL (≥ 3)

## ⚙️ Requirements

- **MATLAB Version**: R2022b (9.13.0.2193358) — tested with Update 5
- **Required Toolbox**:
  - Statistics and Machine Learning Toolbox (version 12.4)

## 📦 Dependencies

The script relies on the following local functions:

- `MMMHC_sim.m` 
- `ag2mag.m` 
- `mag2pag.m`