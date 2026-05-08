# MicrogliaChromBPNet
Final Project for NS219: Encoder-Decoder Models for Neuroscience

**Author:** David Aley  
**Lab:** Corces Lab, UCSF/Gladstone Institutes  
**Date:** May 7, 2026

---

## Background

Large-scale genome-wide association studies (GWAS) have identified dozens of loci associated with AD risk, including variants near *APOE*, *BIN1*, *CLU*, and *TREM2*, and similarly for PD near *SNCA*, *LRRK2*, and *GBA*. However, the vast majority of these variants fall outside protein-coding sequences, making their functional interpretation challenging. Understanding *how* these noncoding variants alter gene regulation requires knowledge of the cell-type-specific regulatory landscape (i.e. which genomic regions are accessible, which transcription factors (TFs) bind there, and how genetic variation disrupts TF binding).

Chromatin accessibility, measured by ATAC-seq, provides a genome-wide readout of regulatory element activity, marking active enhancers and promoters where TFs bind and modulate gene expression. Critically, chromatin accessibility is highly cell type-specific, meaning that to functionally interpret GWAS variants we need cell type-resolved models of the regulatory genome.

Microglia are the resident immune cells of the brain and among the most genetically implicated cell types in both AD and PD. They exist in distinct functional states: **homeostatic microglia** maintain brain homeostasis under normal conditions, while **disease-associated microglia (DAM)** adopt an activated state in neurodegeneration, characterized by upregulation of *TREM2*, *SPP1*, and *APOE* vs. *P2RY12*, *CX3CR1*, and *TMEM119* in homeostatic cells. Whether disease-associated variants differentially affect chromatin accessibility across these states is an open and important question.

This project trains cell state-specific **ChromBPNet** models on single-nucleus ATAC-seq data from PD patient-derived microglia to:
1. Learn sequence models of chromatin accessibility for DAM vs homeostatic microglia
2. Evaluate model performance at base-pair resolution
3. Predict the effect of AD/PD GWAS variants on chromatin accessibility in each microglial state

ChromBPNet is a dilated convolutional neural network that takes 2114bp DNA sequences as input and predicts base-pair resolution ATAC-seq signal. It uses a two-component architecture: a **bias model** that captures Tn5 insertion sequence preference, and a **ChromBPNet model** that learns cell-type-specific TF binding patterns after bias correction.

---

## Dependencies

```bash
conda create -n chrombpnet python=3.8
conda activate chrombpnet
pip install chrombpnet
conda install -c bioconda samtools bedtools macs2
pip install deeptools logomaker h5py matplotlib pandas numpy
```

R packages:
```r
# CRAN packages
install.packages(c("tidyverse", "ggplot2", "readr", "tidyr", 
                   "dplyr", "patchwork", "ggVennDiagram"))

# Bioconductor packages
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install(c("ArchR", "rtracklayer"))
```

---

## Data

- **Single-nucleus multiome data**: Human postmortem PD brain tissue from 5 brain regions (MTG, PUT, CING, CBL, SN)
- **Microglia ATAC-seq object**: 196,131 cells (ArchR project)
- **AD/PD GWAS variants**: ~11,000 single-nucleotide variants (SNVs)
- **Reference genome**: hg38

---

## Step 1: Microglial State Annotation

See `scripts/R/get_microglia_ATAC_barcodes.R` for details. That data is too large to upload to this repository, however if you have any microglia-specific ATAC-seq ArchR project, the code should work as intended.

### 1a. ATAC-based annotation

Load the ArchR project and compute average DAM/homeostatic gene scores per cell from the GeneScoreMatrix.

```r
gsm <- getMatrixFromProject(proj, useMatrix = "GeneScoreMatrix")
```

Marker genes used:
- **Homeostatic**: P2RY12, CX3CR1, TMEM119, CSF1R, SALL1
- **DAM**: TREM2, SPP1, CD9, LPL, APOE, CST7
---

### 1b. Barcode selection
Select top 10,000 non-overlapping DAM and homeostatic barcodes based on ATAC gene scores.

---

## Step 2: BAM Subsetting

See `scripts/Bash/subset_microglia_bam.sh` for details.

Subset the merged microglia BAM by cell barcode to create subtype-specific BAMs.

```bash
# Strip sample# prefix from ArchR barcodes
sed 's/.*#//' ATAC_homeostatic_barcodes.txt > ATAC_homeostatic_barcodes_stripped.txt

# Subset BAM
samtools view -h -D CB:ATAC_homeostatic_barcodes_stripped.txt \
    subsampled_Microglia.bam \
    | samtools sort -o homeostatic_microglia.bam
samtools index homeostatic_microglia.bam
```

**Output:**
- `homeostatic_microglia.bam` — 3.61 GB
- `DAM_microglia.bam` — 3.44 GB

---

## Step 3: Peak Calling & Preprocessing

### 3a. Call peaks with MACS2

See `scripts/Bash/call_microglia_peaks.sh` for details.

```bash
macs2 callpeak \
    -t homeostatic_microglia.bam \
    -f BAM -n homeostatic \
    --outdir peaks/ \
    -p 0.01 --nomodel --shift -100 --extsize 200 --keep-dup all
```

| Subtype | Raw peaks | After filtering |
|---------|-----------|-----------------|
| Homeostatic | 93,483 | 92,285 |
| DAM | 103,858 | 102,077 |

### 3b. Filter blacklist regions

See `scripts/Bash/filter_blacklist_regions.sh` for details.

```bash
bedtools slop -i blacklist.bed.gz -g hg38.chrom.sizes -b 1057 > temp_blacklist.bed
bedtools intersect -v -a homeostatic_peaks.narrowPeak -b temp_blacklist.bed \
    > homeostatic_peaks_no_blacklist_filtered.bed
```

### 3c. Generate non-peak background regions

See `scripts/Bash/prep_nonpeaks_microglia.sh` for details.

```bash
chrombpnet prep nonpeaks \
    -g hg38.fa \
    -p homeostatic_peaks_no_blacklist_filtered.bed \
    -c hg38.chrom.sizes \
    -fl fold_0.json \
    -br blacklist.bed.gz \
    -o nonpeaks/homeostatic
```

**Chromosome splits** (reused from ENCODE tutorial):
- Train: chr2, chr4, chr5, chr7, chr9-19, chr21, chr22
- Validation: chr8, chr20
- Test: chr1, chr3, chr6

---

## Step 4: Bias Model Training

See `scripts/Bash/train_bias_model_homeostatic.sh` and `scripts/Bash/train_bias_model_DAM.sh` for details.

Train a Tn5 insertion bias model for each subtype (GPU required).

```bash
chrombpnet bias pipeline \
    -ibam homeostatic_microglia.bam \
    -d ATAC \
    -g hg38.fa \
    -c hg38.chrom.sizes \
    -p homeostatic_peaks_no_blacklist_filtered.bed \
    -n nonpeaks/homeostatic_negatives.bed \
    -fl fold_0.json \
    -b 0.5 \
    -o bias_model/homeostatic \
    -fp homeostatic
```

---

## Step 5: ChromBPNet Model Training

See `scripts/Bash/train_chrombpnet_homeostatic.sh` and `scripts/Bash/train_chrombpnet_DAM.sh` for details.

Train the full ChromBPNet model using the trained bias model (GPU required).

```bash
chrombpnet pipeline \
    -ibam homeostatic_microglia.bam \
    -d ATAC \
    -g hg38.fa \
    -c hg38.chrom.sizes \
    -p homeostatic_peaks_no_blacklist_filtered.bed \
    -n nonpeaks/homeostatic_negatives.bed \
    -fl fold_0.json \
    -b bias_model/homeostatic/models/homeostatic_bias.h5 \
    -o chrombpnet_model/homeostatic \
    -fp homeostatic
```

**GPU job submission** (Wynton HPC):
```bash
#$ -q gpu.q
#$ -l gpu_mem=5000
#$ -l h_rt=72:00:00
module load cuda
export CUDA_VISIBLE_DEVICES=$SGE_GPU
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:$LD_LIBRARY_PATH
```

---

## Step 6: Model Evaluation

### 6a. Quantitative metrics

| Metric | DAM | Homeostatic |
|--------|-----|-------------|
| Counts Pearson R | 0.680 | 0.650 |
| Counts Spearman R | 0.612 | 0.573 |
| Profile JSD | 0.598 | 0.576 |
| Profile norm JSD | 0.211 | 0.231 |

### 6b. Predicted vs observed bigwigs
Generate predicted accessibility bigwigs and compare to observed ATAC signal at specific loci across training, validation, and test chromosomes.

```bash
# Generate predicted bigwig
chrombpnet pred_bw \
    -cmb chrombpnet_model/DAM/models/DAM_chrombpnet_nobias.h5 \
    -r peaks/DAM_peaks_no_blacklist_filtered.bed \
    -g hg38.fa \
    -c hg38.chrom.sizes \
    -op chrombpnet_model/DAM/predictions/DAM

# Generate observed bigwig
bamCoverage \
    -b DAM_microglia.bam \
    -o DAM_observed.bw \
    --normalizeUsing RPKM \
    --binSize 10 \
    --numberOfProcessors 4
```

---

## Step 7: Variant Effect Prediction

Predict the effect of AD and PD GWAS variants on chromatin accessibility using the Corces Lab Batch Query Predictor (BQP) tool.

### 7a. Prepare variant files
Variants filtered to SNVs only (single nucleotide, no indels) and split into four sets:
- AD GWAS variants overlapping peaks (n=1,671)
- AD GWAS variants outside peaks (n=6,780)
- PD GWAS variants overlapping peaks (n=560)
- PD GWAS variants outside peaks (n=1,518)

### 7b. Run BQP
```bash
python3 /gladstone/corces/lab/Shared/tools/bqpapplication/run_bqp.py \
    --modelPath BQP_models/DAM \
    --inputFile variants/AD_in_peak.txt \
    --outputDir VariantEffectPrediction/DAM/AD_in_peak
```

### 7c. Visualize top variants
See `scripts/compare_variant_predictions_DAM_homeostatic.ipynb` for code to visualize predicted profiles and sequence importance scores (DeepSHAP) for top variants side-by-side across DAM and homeostatic models.

---

## Results Summary

- Successfully trained ChromBPNet models for DAM and homeostatic microglia
- Models achieve Pearson R ~0.65-0.68 on held-out peaks
- Variant effect predictions show higher predicted effect sizes (signed JSD) for variants overlapping peaks vs outside peaks, validating model specificity
- Top variants with largest predicted effects in both DAM and homeostatic states identified for follow-up visualization

---

## References

- Pampari et al. (2023). ChromBPNet: Bias factorized, base-resolution deep learning models of chromatin accessibility. *bioRxiv*.
- Menon & Turner et al. (2026). Massive-scale single-nucleus multi-omics identifies novel rare noncoding drivers of Parkinson's disease. *bioRxiv*.
