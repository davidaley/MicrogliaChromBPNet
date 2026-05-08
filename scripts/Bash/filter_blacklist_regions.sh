#!/bin/bash
#$ -S /bin/bash
#$ -o /gladstone/corces/lab/users/daley/PD_microglia/logs/blacklist_filter.out
#$ -e /gladstone/corces/lab/users/daley/PD_microglia/logs/blacklist_filter.err
#$ -cwd
#$ -j y
#$ -l mem_free=16G
#$ -l scratch=50G
#$ -l h_rt=1:00:00
#$ -r y

echo "Job started: $(date)"
echo "Running on host: $(hostname)"

module load CBI miniforge3
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chrombpnet

echo "Conda env activated: $(date)"

BLACKLIST=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial/data/downloads/blacklist.bed.gz
CHROM_SIZES=/gladstone/corces/lab/users/daley/chrombpnet/chrombpnet_tutorial/data/downloads/hg38.chrom.sizes
PEAK_DIR=/gladstone/corces/lab/users/daley/PD_microglia/ChromatinAccessibility/peaks

echo "Extending blacklist by 1057bp: $(date)"
bedtools slop -i $BLACKLIST -g $CHROM_SIZES -b 1057 > $PEAK_DIR/temp_blacklist.bed

echo "Filtering homeostatic peaks: $(date)"
bedtools intersect -v -a $PEAK_DIR/homeostatic_peaks.narrowPeak \
    -b $PEAK_DIR/temp_blacklist.bed \
    > $PEAK_DIR/homeostatic_peaks_no_blacklist.bed

echo "Filtering DAM peaks: $(date)"
bedtools intersect -v -a $PEAK_DIR/DAM_peaks.narrowPeak \
    -b $PEAK_DIR/temp_blacklist.bed \
    > $PEAK_DIR/DAM_peaks_no_blacklist.bed

echo "Peaks remaining after blacklist filtering:"
wc -l $PEAK_DIR/homeostatic_peaks_no_blacklist.bed $PEAK_DIR/DAM_peaks_no_blacklist.bed

echo "Cleaning up temp files: $(date)"
rm $PEAK_DIR/temp_blacklist.bed

echo "Job finished: $(date)"

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"