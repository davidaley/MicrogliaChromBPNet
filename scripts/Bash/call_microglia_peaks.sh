#!/bin/bash
#$ -S /bin/bash
#$ -o /gladstone/corces/lab/users/daley/PD_microglia/logs/macs2_peaks.out
#$ -e /gladstone/corces/lab/users/daley/PD_microglia/logs/macs2_peaks.err
#$ -cwd
#$ -j y
#$ -l mem_free=32G
#$ -l scratch=50G
#$ -l h_rt=12:00:00
#$ -r y

echo "Job started: $(date)"
echo "Running on host: $(hostname)"

module load CBI miniforge3
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chrombpnet

echo "Conda env activated: $(date)"

BAM_DIR=/gladstone/corces/lab/users/daley/PD_microglia/ChromatinAccessibility
PEAK_DIR=/gladstone/corces/lab/users/daley/PD_microglia/ChromatinAccessibility/peaks
mkdir -p $PEAK_DIR

echo "Calling peaks for homeostatic microglia: $(date)"
macs2 callpeak \
    -t $BAM_DIR/homeostatic_microglia.bam \
    -f BAM \
    -n homeostatic \
    --outdir $PEAK_DIR \
    -p 0.01 \
    --nomodel \
    --shift -100 \
    --extsize 200 \
    --keep-dup all

echo "Calling peaks for DAM microglia: $(date)"
macs2 callpeak \
    -t $BAM_DIR/DAM_microglia.bam \
    -f BAM \
    -n DAM \
    --outdir $PEAK_DIR \
    -p 0.01 \
    --nomodel \
    --shift -100 \
    --extsize 200 \
    --keep-dup all

echo "Done: $(date)"

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"