#!/bin/bash
#$ -S /bin/bash
#$ -o /gladstone/corces/lab/users/daley/PD_microglia/logs
#$ -e /gladstone/corces/lab/users/daley/PD_microglia/logs
#$ -cwd
#$ -j y
#$ -l mem_free=32G
#$ -l scratch=100G
#$ -l h_rt=12:00:00
#$ -r y

echo "Job started: $(date)"
echo "Running on host: $(hostname)"

module load CBI miniforge3
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chrombpnet

echo "Conda env activated: $(date)"

MICROGLIA_BAM=/gladstone/corces/lab/users/smenon/2304_PDMultiome_Final/Final_Objects/Scripts/ChromatinAccessibility/Microglia_Subsampled/subsampled_Microglia.bam
OUT_DIR=/gladstone/corces/lab/users/daley/PD_microglia/ChromatinAccessibility

# Homeostatic
echo "Subsetting homeostatic BAM: $(date)"
samtools view -h -D CB:${OUT_DIR}/ATAC_homeostatic_barcodes_stripped.txt \
    $MICROGLIA_BAM \
    | samtools sort -o ${OUT_DIR}/homeostatic_microglia.bam
echo "Indexing homeostatic BAM: $(date)"
samtools index ${OUT_DIR}/homeostatic_microglia.bam
echo "Homeostatic BAM flagstat:"
samtools flagstat ${OUT_DIR}/homeostatic_microglia.bam

# DAM
echo "Subsetting DAM BAM: $(date)"
samtools view -h -D CB:${OUT_DIR}/ATAC_dam_barcodes_stripped.txt \
    $MICROGLIA_BAM \
    | samtools sort -o ${OUT_DIR}/DAM_microglia.bam
echo "Indexing DAM BAM: $(date)"
samtools index ${OUT_DIR}/DAM_microglia.bam
echo "DAM BAM flagstat:"
samtools flagstat ${OUT_DIR}/DAM_microglia.bam

echo "Job finished: $(date)"

[[ -n "$JOB_ID" ]] && qstat -j "$JOB_ID"