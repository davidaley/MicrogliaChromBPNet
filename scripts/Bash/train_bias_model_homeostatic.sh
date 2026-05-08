#!/bin/bash
#$ -S /bin/bash
#$ -o /gladstone/corces/lab/users/daley/PD_microglia/logs
#$ -e /gladstone/corces/lab/users/daley/PD_microglia/logs
#$ -cwd
#$ -j y
#$ -q gpu.q
#$ -l mem_free=32G
#$ -l scratch=50G
#$ -l h_rt=72:00:00
#$ -l gpu_mem=5000
#$ -l hostname=!qb3-idgpu10
#$ -r y

echo "Job started: $(date)"
echo "Running on host: $(hostname)"

module load CBI miniforge3
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chrombpnet

# module load cuda/11.5
module load cuda
echo "SGE_GPU: $SGE_GPU"
export CUDA_VISIBLE_DEVICES=${SGE_GPU:-0}
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH

echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
nvidia-smi

echo "TF GPU test: $(python -c 'import tensorflow as tf; print(tf.config.list_physical_devices("GPU"))')"

BASE=/gladstone/corces/lab/users/daley/PD_microglia
TUTORIAL=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial

mkdir -p $BASE/bias_model/homeostatic

echo "Training homeostatic bias model: $(date)"
chrombpnet bias pipeline \
    -ibam $BASE/ChromatinAccessibility/homeostatic_microglia.bam \
    -d ATAC \
    -g $TUTORIAL/data/downloads/hg38.fa \
    -c $TUTORIAL/data/downloads/hg38.chrom.sizes \
    -p $BASE/ChromatinAccessibility/peaks/homeostatic_peaks_no_blacklist_filtered.bed \
    -n $BASE/ChromatinAccessibility/nonpeaks/homeostatic_negatives.bed \
    -fl $TUTORIAL/data/splits/fold_0.json \
    -b 0.5 \
    -o $BASE/bias_model/homeostatic/ \
    -fp homeostatic

echo "Job finished: $(date)"
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"