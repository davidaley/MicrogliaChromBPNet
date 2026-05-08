#!/bin/bash
#$ -S /bin/bash
#$ -o /gladstone/corces/lab/users/daley/PD_microglia/logs/generate_predicted_bigwigs.out
#$ -e /gladstone/corces/lab/users/daley/PD_microglia/logs/generate_predicted_bigwigs.err
#$ -cwd
#$ -j y
#$ -q gpu.q
#$ -l mem_free=32G
#$ -l scratch=50G
#$ -l h_rt=48:00:00
#$ -l gpu_mem=5000
#$ -l hostname=!qb3-idgpu10
#$ -r y

echo "Job started: $(date)"
echo "Running on host: $(hostname)"

module load CBI miniforge3
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chrombpnet

module load cuda
export CUDA_VISIBLE_DEVICES=${SGE_GPU:-0}
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH

echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
nvidia-smi
echo "TF GPU test: $(python -c 'import tensorflow as tf; print(tf.config.list_physical_devices("GPU"))')"

BASE=/gladstone/corces/lab/users/daley/PD_microglia
TUTORIAL=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial

mkdir -p $BASE/chrombpnet_model/DAM/predictions
mkdir -p $BASE/chrombpnet_model/homeostatic/predictions

echo "Generating DAM predicted bigwig: $(date)"
chrombpnet pred_bw \
    -cmb $BASE/chrombpnet_model/DAM/models/DAM_chrombpnet_nobias.h5 \
    -r $BASE/ChromatinAccessibility/peaks/DAM_peaks_no_blacklist_filtered.bed \
    -g $TUTORIAL/data/downloads/hg38.fa \
    -c $TUTORIAL/data/downloads/hg38.chrom.sizes \
    -op $BASE/chrombpnet_model/DAM/predictions \

echo "Generating homeostatic predicted bigwig: $(date)"
chrombpnet pred_bw \
    -cmb $BASE/chrombpnet_model/homeostatic/models/homeostatic_chrombpnet_nobias.h5 \
    -r $BASE/ChromatinAccessibility/peaks/homeostatic_peaks_no_blacklist_filtered.bed \
    -g $TUTORIAL/data/downloads/hg38.fa \
    -c $TUTORIAL/data/downloads/hg38.chrom.sizes \
    -op $BASE/chrombpnet_model/homeostatic/predictions \

echo "Job finished: $(date)"
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"