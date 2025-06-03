import pandas as pd
import numpy as np
import os

# === Set Java environment (adjust to your machine) ===
os.environ["JAVA_HOME"] = "C:/Program Files/Java/jdk-21"

# === Import Tetrad via PyTetrad ===
import pytetrad.tools.TetradSearch as ts
import pytetrad.tools.translate as tr
import edu.cmu.tetrad.search.test as test
import edu.cmu.tetrad.search.score as score

# === Benchmark parameters ===
X = ["N50", "N150"]
N_path = ["100", "250", "500", "1000", "5000", "10000", "20000"]
degree = ["3", "5"]
LV = ["0L", "10L", "20L"]
nb_rep = 30

# === Paths to input/output directories ===
path_linear = "simulated_data/continuous/linear_gaussian"
path_non_linear = "simulated_data/continuous/non_linear"
path_output_linear = "results/continuous/linear_gaussian/GFCI"
path_output_non_linear = "results/continuous/non_linear/GFCI"

# === Main execution function ===
def run_gfci_pipeline(data_type):
    if data_type == "linear":
        input_root = path_linear
        output_root = path_output_linear
        # Linear settings
        test_type = "fisher_z"
        score_type = "sem_bic"
        gfci_params = {"depth": 5, "max_disc_path_length": 5}

    elif data_type == "nonlinear":
        input_root = path_non_linear
        output_root = path_output_non_linear
        # Nonlinear settings
        test_type = "degenerate_gaussian"
        score_type = "basis_function_bic"
        gfci_params = {"depth": 3, "max_disc_path_length": 2}

    else:
        raise ValueError("Invalid data_type. Must be 'linear' or 'nonlinear'.")

    for x in X:
        for dg in degree:
            for n in N_path:
                for lv in LV:
                    for idx_rep in range(1, nb_rep + 1):
                        filename = f"input_{lv}_{idx_rep}.csv"
                        path_file = os.path.join(input_root, x, dg, n, filename)

                        if not os.path.isfile(path_file):
                            print(f"[WARNING] File not found: {path_file}")
                            continue

                        # === Load dataset ===
                        data = pd.read_csv(path_file, header=None)
                        if not isinstance(data.iloc[0, 0], float):
                            data = pd.read_csv(path_file)  # fallback if header detected

                        # === Prepare output directory ===
                        out_dir = os.path.join(output_root, x, dg, n)
                        os.makedirs(out_dir, exist_ok=True)

                        output_file = os.path.join(out_dir, f"adj_GFCI_{lv}_{idx_rep}.csv")

                        # === Configure GFCI ===
                        search = ts.TetradSearch(data)
                        search.set_verbose(True)

                        # === Select test and score based on data type ===
                        if test_type == "fisher_z":
                            search.use_fisher_z(alpha=0.05)
                        elif test_type == "degenerate_gaussian":
                            search.use_degenerate_gaussian_test(alpha=0.05)

                        if score_type == "sem_bic":
                            search.use_sem_bic(penalty_discount=5)
                        elif score_type == "basis_function_bic":
                            search.use_basis_function_bic(truncation_limit=3, penalty_discount=2)

                        # === Run GFCI with appropriate parameters ===
                        search.run_gfci(
                            depth=gfci_params["depth"],
                            max_disc_path_length=gfci_params["max_disc_path_length"]
                        )

                        # === Export PAG matrix ===
                        matrix_pag = search.get_graph_to_matrix()
                        matrix_pag.to_csv(output_file, index=False, header=False)


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python run_gfci.py [linear|nonlinear]")
        sys.exit(1)

    run_gfci_pipeline(sys.argv[1])