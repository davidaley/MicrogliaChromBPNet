#!/bin/bash
#$ -S /bin/bash
#$ -o /gladstone/corces/lab/users/daley/PD_microglia/logs/prep_nonpeaks.out
#$ -e /gladstone/corces/lab/users/daley/PD_microglia/logs/prep_nonpeaks.err
#$ -cwd
#$ -j y
#$ -l mem_free=32G
#$ -l scratch=50G
#$ -l h_rt=4:00:00
#$ -r y

echo "Job started: $(date)"
echo "Running on host: $(hostname)"

module load CBI miniforge3
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chrombpnet

echo "Conda env activated: $(date)"

# Reference files (reusing from tutorial)
GENOME=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial/data/downloads/hg38.fa
CHROM_SIZES=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial/data/downloads/hg38.chrom.sizes
BLACKLIST=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial/data/downloads/blacklist.bed.gz

# Chromosome fold splits (reusing from tutorial)
# Splits: test=chr1,chr3,chr6 | valid=chr8,chr20 | train=remaining
FOLD=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial/data/splits/fold_0.json

# Microglia peak files (blacklist-filtered)
PEAK_DIR=/gladstone/corces/lab/users/daley/PD_microglia/ChromatinAccessibility/peaks

# Output directory for nonpeaks
OUT_DIR=/gladstone/corces/lab/users/daley/PD_microglia/ChromatinAccessibility
mkdir -p $OUT_DIR/nonpeaks


echo "Generating nonpeaks for homeostatic microglia: $(date)"
chrombpnet prep nonpeaks \
    -g $GENOME \
    -p $PEAK_DIR/homeostatic_peaks_no_blacklist_filtered.bed \
    -c $CHROM_SIZES \
    -fl $FOLD \
    -br $BLACKLIST \
    -o $OUT_DIR/nonpeaks/homeostatic

echo "Generating nonpeaks for DAM microglia: $(date)"
chrombpnet prep nonpeaks \
    -g $GENOME \
    -p $PEAK_DIR/DAM_peaks_no_blacklist_filtered.bed \
    -c $CHROM_SIZES \
    -fl $FOLD \
    -br $BLACKLIST \
    -o $OUT_DIR/nonpeaks/DAM

echo "Nonpeak counts:"
wc -l $OUT_DIR/nonpeaks/homeostatic_negatives.bed
wc -l $OUT_DIR/nonpeaks/DAM_negatives.bed

echo "Job finished: $(date)"

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"