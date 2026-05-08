#!/bin/bash
#$ -S /bin/bash
#$ -o /gladstone/corces/lab/users/daley/PD_microglia/logs/generate_observed_bigwigs.out
#$ -e /gladstone/corces/lab/users/daley/PD_microglia/logs/generate_observed_bigwigs.err
#$ -cwd
#$ -j y
#$ -l mem_free=32G
#$ -l scratch=50G
#$ -l h_rt=24:00:00
#$ -r y

echo "Job started: $(date)"
echo "Running on host: $(hostname)"

module load CBI miniforge3
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chrombpnet

BASE=/gladstone/corces/lab/users/daley/PD_microglia

echo "Generating DAM observed bigwig: $(date)"
bamCoverage \
    -b $BASE/ChromatinAccessibility/DAM_microglia.bam \
    -o $BASE/ChromatinAccessibility/DAM_observed.bw \
    --normalizeUsing RPKM \
    --binSize 1 \
    --numberOfProcessors 4

echo "Generating homeostatic observed bigwig: $(date)"
bamCoverage \
    -b $BASE/ChromatinAccessibility/homeostatic_microglia.bam \
    -o $BASE/ChromatinAccessibility/homeostatic_observed.bw \
    --normalizeUsing RPKM \
    --binSize 1 \
    --numberOfProcessors 4

echo "Job finished: $(date)"
[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"