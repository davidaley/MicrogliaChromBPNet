library(readr)
library(dplyr)
library(tidyr)

# Load in AD and PD GWAS variants
variants_df <- read_tsv("/gladstone/corces/lab/users/daley/PD_microglia/BQP_models/input_vars.txt")

# Format data properly for variant prediction
bqp_input <- variants_df %>%
  dplyr::select(chr, pos, ref, alt, var_id) %>%
  dplyr::rename(posID = var_id)

# Check to see details about variant set
table(variants_df$in_peak)
table(variants_df$Disease)

dir.create("/gladstone/corces/lab/users/daley/PD_microglia/BQP_models/variants/", recursive = TRUE)
VARIANTS_DIR <- "/gladstone/corces/lab/users/daley/PD_microglia/VariantEffectPrediction/variants"

# Helper function to clean and filter variants -> removing indels and multi-allelic variants
clean_variants <- function(df) {
  df %>%
    dplyr::filter(
      !is.na(chr), !is.na(pos), !is.na(ref), !is.na(alt), !is.na(posID),
      ref %in% c("A", "T", "C", "G"),
      alt %in% c("A", "T", "C", "G")
    )
}

# AD variant in peak
ad_in_peak <- variants_df %>%
  dplyr::filter(Disease == "AD", in_peak == TRUE) %>%
  dplyr::select(chr, pos, ref, alt, var_id) %>%
  dplyr::rename(posID = var_id)
ad_in_peak_clean <- clean_variants(ad_in_peak)
write_tsv(ad_in_peak_clean, file.path(VARIANTS_DIR, "AD_in_peak.txt"))

# AD variant not in peak
ad_not_in_peak <- variants_df %>%
  dplyr::filter(Disease == "AD", in_peak == FALSE) %>%
  dplyr::select(chr, pos, ref, alt, var_id) %>%
  dplyr::rename(posID = var_id)
ad_not_in_peak_clean <- clean_variants(ad_not_in_peak)
write_tsv(ad_not_in_peak_clean, file.path(VARIANTS_DIR, "AD_not_in_peak.txt"))

# PD variant in peak
pd_in_peak <- variants_df %>%
  dplyr::filter(Disease == "PD", in_peak == TRUE) %>%
  dplyr::select(chr, pos, ref, alt, var_id) %>%
  dplyr::rename(posID = var_id)
pd_in_peak_clean <- clean_variants(pd_in_peak)
write_tsv(pd_in_peak_clean, file.path(VARIANTS_DIR, "PD_in_peak.txt"))

# PD variant not in peak
pd_not_in_peak <- variants_df %>%
  dplyr::filter(Disease == "PD", in_peak == FALSE) %>%
  dplyr::select(chr, pos, ref, alt, var_id) %>%
  dplyr::rename(posID = var_id)
pd_not_in_peak_clean <- clean_variants(pd_not_in_peak)
write_tsv(pd_not_in_peak_clean, file.path(VARIANTS_DIR, "PD_not_in_peak.txt"))

message("AD in peak: ", nrow(ad_in_peak_clean))
message("AD not in peak: ", nrow(ad_not_in_peak_clean))
message("PD in peak: ", nrow(pd_in_peak_clean))
message("PD not in peak: ", nrow(pd_not_in_peak_clean))


BATCH_SIZE <- 500

# Function to save variants in chunks (otherwise, variant prediction would time out on Wynton HPC)
save_chunks <- function(df, set_name) {
  chunk_dir <- file.path(VARIANTS_DIR, set_name)
  dir.create(chunk_dir, recursive = TRUE, showWarnings = FALSE)
  
  n <- nrow(df)
  n_batches <- ceiling(n / BATCH_SIZE)
  
  for (i in seq_len(n_batches)) {
    start <- (i - 1) * BATCH_SIZE + 1
    end <- min(i * BATCH_SIZE, n)
    chunk <- df[start:end, ]
    write_tsv(chunk, file.path(chunk_dir, paste0("batch_", i - 1, ".txt")))
  }
  message(set_name, ": ", n, " variants split into ", n_batches, " batches")
}

save_chunks(ad_in_peak_clean,      "AD_in_peak")
save_chunks(ad_not_in_peak_clean,  "AD_not_in_peak")
save_chunks(pd_in_peak_clean,      "PD_in_peak")
save_chunks(pd_not_in_peak_clean,  "PD_not_in_peak")
