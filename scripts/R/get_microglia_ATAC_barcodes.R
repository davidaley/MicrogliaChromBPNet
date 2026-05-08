library(ArchR)
library(dplyr)

PD_dir <- "/gladstone/corces/lab/users/smenon/2304_PDMultiome_Final/"
proj <- loadArchRProject(paste0(PD_dir, 
                                "Final_Objects/ChromatinAccessibility/CellType_Projects/Microglia_GEX_ATAC"))

# Plot microglia ATAC UMAP
p1 <- plotEmbedding(proj, 
                    embedding = "UMAP_Harmony_ATAC_GEX",
                    colorBy = "cellColData",
                    name = "CellType_Annotation",
                    rastr = TRUE)

# Load microglial marker genes
microglial_marker_genes <- read_tsv(paste0(PD_microglia_dir, "microglial_marker_genes.tsv"))

gene_df <- microglial_marker_genes %>%
  filter(cell_type == !!cell_type)

genes <- gene_df %>%
  pull(gene) %>%
  unique()

category_lookup <- setNames(gene_df$marker_category, gene_df$gene)
message("  Found ", length(genes), " marker genes for ", cell_type)


# Build gene set lists from marker categories
homeostatic_genes <- gene_df %>%
  filter(marker_category == "Homeostatic") %>%
  pull(gene)

dam_genes <- gene_df %>%
  filter(grepl("DAM", marker_category)) %>%
  pull(gene)

message("Homeostatic genes: ", paste(homeostatic_genes, collapse = ", "))
message("DAM genes: ", paste(dam_genes, collapse = ", "))


# Visualize homeostatic and DAM gene score markers in ATAC UMAP
p_homeostatic <- plotEmbedding(
  proj,
  embedding = "UMAP_Harmony_ATAC_GEX",
  colorBy = "GeneScoreMatrix",
  name = homeostatic_genes,
  rastr = TRUE
)

p_dam <- plotEmbedding(
  proj,
  embedding = "UMAP_Harmony_ATAC_GEX",
  colorBy = "GeneScoreMatrix",
  name = dam_genes,
  rastr = TRUE
)

atac_plot_dir <- "/gladstone/corces/lab/users/daley/PD_microglia/ChromatinAccessibility"
dir.create(atac_plot_dir, recursive = TRUE)

pdf(file.path(atac_plot_dir, "Microglia_ATAC_GeneScores.pdf"), width = 6, height = 5)
for (p in c(p_homeostatic, p_dam)) print(p)
dev.off()


# Get gene score matrix for our marker genes
gsm <- getMatrixFromProject(
  proj,
  useMatrix = "GeneScoreMatrix",
  useSeqnames = NULL
)

# Extract the matrix and gene names
gs_matrix <- assay(gsm, "GeneScoreMatrix")
gene_names <- rowData(gsm)$name

# Subset to our marker genes
homeostatic_idx <- which(gene_names %in% homeostatic_genes)
dam_idx <- which(gene_names %in% dam_genes)

# Calculate average score per cell per gene set
homeostatic_avg <- colMeans(gs_matrix[homeostatic_idx, ])
dam_avg <- colMeans(gs_matrix[dam_idx, ])

# Add to a dataframe
atac_scores <- data.frame(
  barcode = colnames(gs_matrix),
  homeostatic_avg = homeostatic_avg,
  dam_avg = dam_avg
)

# First rank cells by each score
atac_scores <- atac_scores %>%
  dplyr::mutate(
    homeostatic_rank = rank(-homeostatic_avg),
    dam_rank = rank(-dam_avg)
  )

# Get top DAM cells first
atac_dam_barcodes <- atac_scores %>%
  dplyr::arrange(dplyr::desc(dam_avg)) %>%
  head(10000) %>%
  pull(barcode)

# Get top homeostatic cells, excluding any already in DAM set
atac_homeostatic_barcodes <- atac_scores %>%
  dplyr::filter(!barcode %in% atac_dam_barcodes) %>%
  dplyr::arrange(dplyr::desc(homeostatic_avg)) %>%
  head(10000) %>%
  pull(barcode)

# Verify no overlap
message("Overlap: ", length(intersect(atac_homeostatic_barcodes, atac_dam_barcodes)))

# Save homeostatic microglia and DAM ATAC barcodes
write.table(atac_homeostatic_barcodes,
            file.path(atac_plot_dir, "ATAC_homeostatic_barcodes.txt"),
            quote = FALSE, row.names = FALSE, col.names = FALSE)

write.table(atac_dam_barcodes,
            file.path(atac_plot_dir, "ATAC_dam_barcodes.txt"),
            quote = FALSE, row.names = FALSE, col.names = FALSE)