import argparse
import os
import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder
from causallearn.search.ConstraintBased.FCI import fci

def adj_fci(file: str) -> pd.DataFrame:
    """
    Infer the PAG using the FCI algorithm with the G-squared test.

    Args:
        file (str): CSV file path

    Returns:
        pd.DataFrame: PAG adjacency matrix
    """
    data = pd.read_csv(file)
    encoders = {}
    for col in data.columns:
        le = LabelEncoder()
        data[col] = le.fit_transform(data[col])
    g, edges = fci(data.to_numpy(), independence_test_method="gsq", alpha=0.05)
    matrix_pag = g.graph
    nm = list(data.columns)
    pag_df = pd.DataFrame(matrix_pag, index=nm, columns=nm)
    return pag_df


def main():
    parser = argparse.ArgumentParser(description="Run FCI on simulated data")
    parser.add_argument("--name", type=str, required=True, help="Model name (e.g., Alarm)")
    parser.add_argument("--sample_sizes", type=str, required=True, help="Comma-separated list of sample sizes")
    parser.add_argument("--rep_idx", type=int, required=True, help="Replication ID")
    parser.add_argument("--path_input", type=str, required=True, help="Input data root path")
    parser.add_argument("--path_output", type=str, required=True, help="Output data root path")

    args = parser.parse_args()
    sample_sizes = [int(s) for s in args.sample_sizes.split(",")]
    latents = ["0L", "10L", "20L"]

    for n in sample_sizes:
        for latent in latents:
            filename = f"input_{latent}_{args.rep_idx}.csv"
            input_path = os.path.join(args.path_input, args.name, str(n), filename)
            output_dir = os.path.join(args.path_output, args.name, str(n))
            os.makedirs(output_dir, exist_ok=True)
            output_file = f"adj_FCI_{latent}_{args.rep_idx}.csv"
            output_path = os.path.join(output_dir, output_file)

            if not os.path.exists(input_path):
                print(f"[WARNING] File not found: {input_path}")
                continue

            print(f"Running FCI on {input_path}...")
            pag = adj_fci(input_path)
            pag.to_csv(output_path)
            print(f"Saved PAG to {output_path}")

if __name__ == "__main__":
    main()
