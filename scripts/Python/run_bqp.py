# SCRIPT PROVIDED BY ANNIYSH SIVAKUMAR (CORCES LAB)

import argparse
import subprocess
import os
import sys
import shlex

SIF_IMAGE = "/gladstone/corces/lab/Shared/tools/bqpapplication/batchquerypredictor.sif"


def detect_model_structure(modelPath, parser):

    modelPath = os.path.abspath(modelPath)
    base = os.path.basename(modelPath)
    parent = os.path.dirname(modelPath)

    def has_model_file(dirpath):
        return any(
            f.lower().endswith((".h5", ".hdf5"))
            and os.path.isfile(os.path.join(dirpath, f))
            for f in os.listdir(dirpath)
        )

    # If cell-type directory
    if has_model_file(modelPath):
        model_name = os.path.basename(parent)
        cell_types = [base]
        model_group = parent
        return model_name, cell_types, model_group

    # If model group directory
    available_cell_types = [
        d for d in sorted(os.listdir(modelPath))
        if os.path.isdir(os.path.join(modelPath, d))
        and has_model_file(os.path.join(modelPath, d))
    ]

    if not available_cell_types:
        parser.error(
            f"ERROR: No valid cell-type directories found in '{modelPath}'.\n"
        )

    print(f"\nModel group detected: {base}")
    print("Available cell types:")
    for ct in available_cell_types:
        print(f"  - {ct}")

    user_input = input(
        "\nEnter one or more cell types (comma-separated), or 'all': "
    ).strip()

    if user_input.lower() == "all":
        chosen = available_cell_types
    else:
        ct_lookup = {ct.lower(): ct for ct in available_cell_types}

        chosen = []
        for c in user_input.split(","):
            c = c.strip().lower()
            if not c:
                continue
            if c not in ct_lookup:
                parser.error(
                    f"ERROR: Cell type '{c}' does not exist in model group '{base}'"
                )
            chosen.append(ct_lookup[c])
        if not chosen:
            parser.error("ERROR: No cell types selected.")

    # Validate choices
    for ct in chosen:
        if ct not in available_cell_types:
            parser.error(
                f"ERROR: Cell type '{ct}' does not exist in model group '{base}'"
            )

    model_name = base
    model_group = modelPath
    return model_name, chosen, model_group



def main():
    parser = argparse.ArgumentParser(
        description="Run Batch Query Predictor Application through Apptainer"
    )

    parser.add_argument(
        "--modelPath",
        required=True,
        help="Path to model folder (either <ModelName>/<CellType> or <ModelName>)"
    )
    parser.add_argument(
        "--inputFile",
        required=True,
        help="Variant file (.txt or .tsv)"
    )
    parser.add_argument(
        "--outputDir",
        required=True,
        help="Directory to store results"
    )

    args = parser.parse_args()

    # Validate input file
    if not os.path.isfile(args.inputFile):
        parser.error(f"ERROR: inputFile '{args.inputFile}' does not exist.")

    # Validate output dir
    os.makedirs(args.outputDir, exist_ok=True)


    # Normalize modelPath
    modelPath = os.path.normpath(args.modelPath)
    if not os.path.isdir(modelPath):
        parser.error(f"ERROR: modelPath '{modelPath}' does not exist or is not a directory.")

    # Detect model/cell-type structure
    model_name, cell_types, model_group = detect_model_structure(modelPath, parser)
    parent_models_dir = os.path.dirname(model_group)

    # Convert list to comma-separated for env
    cell_types_env = ",".join(cell_types)

    variant_inside_container = f"/inputs/{os.path.basename(args.inputFile)}"

    # Build Apptainer command
    apptainer_cmd = [
        "apptainer", "exec",
        "--env", f"MODELS_PATH=/models",
        "--env", f"OUTPUT_PATH=/outputs",
        "--env", f"VARIANT_FILE={variant_inside_container}",
        "--env", f"MODEL_NAME={model_name}",
        "--env", f"CELL_TYPES={cell_types_env}",
        "--bind", f"{parent_models_dir}:/models",
        "--bind", f"{os.path.dirname(args.inputFile)}:/inputs",
        "--bind", "/gladstone/corces/lab/Shared/genomes:/gladstone/corces/lab/Shared/genomes",
        "--bind", f"{args.outputDir}:/outputs",
        SIF_IMAGE,
        "python", "/app/run_batch.py"
    ]

    print(" Running Batch Query Predictor")
    print("Model Name:   ", model_name)
    print("Cell Types:   ", ", ".join(cell_types))
    print("Model Folder: ", model_group)
    print("Input File:   ", args.inputFile)
    print("Output Dir:   ", args.outputDir)

    job_script_path = os.path.join(args.outputDir, "job.sh")
    cmd_str = " ".join(shlex.quote(x) for x in apptainer_cmd)

    with open(job_script_path, "w") as f:
        f.write(f"#!/bin/bash\n{cmd_str}\n")
    os.chmod(job_script_path, 0o755)


    stderr_path = os.path.join(args.outputDir, "error.txt")
    stdout_path = os.path.join(args.outputDir, "log.txt")


    # Execute container
    subprocess.run([
    "qsub",
    "-S", "/bin/bash",
    "-cwd",
    "-l", "mem_free=25G",
    "-l", "scratch=5G",
    "-l", "h_rt=75:00:00",
    "-e", stderr_path,
    "-o", stdout_path,
    job_script_path
    ], check=True)


if __name__ == "__main__":
    main()