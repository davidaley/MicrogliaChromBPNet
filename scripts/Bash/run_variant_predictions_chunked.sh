#!/bin/bash

# -------------------------------------------------------------------------
# Paths
# -------------------------------------------------------------------------
BQP=/gladstone/corces/lab/Shared/tools/bqpapplication/run_bqp.py
MODELS=/gladstone/corces/lab/users/daley/PD_microglia/BQP_models
VARIANTS=/gladstone/corces/lab/users/daley/PD_microglia/VariantEffectPrediction/variants
OUT=/gladstone/corces/lab/users/daley/PD_microglia/VariantEffectPrediction
BATCH_SIZE=500
TMP_DIR=/gladstone/corces/lab/users/daley/PD_microglia/VariantEffectPrediction/tmp_batches

mkdir -p $TMP_DIR

# -------------------------------------------------------------------------
# Run BQP for all combinations of cell type and variant set
# splitting each variant file into batches of up to 500 variants
# -------------------------------------------------------------------------
for CELL_TYPE in DAM homeostatic; do
    for VARIANT_SET in AD_in_peak AD_not_in_peak PD_in_peak PD_not_in_peak; do

        INPUT_FILE=$VARIANTS/${VARIANT_SET}.txt

        # Extract header and data lines
        HEADER=$(head -1 $INPUT_FILE)
        TOTAL_VARIANTS=$(tail -n +2 $INPUT_FILE | wc -l)
        NUM_BATCHES=$(( (TOTAL_VARIANTS + BATCH_SIZE - 1) / BATCH_SIZE ))

        echo "Splitting $VARIANT_SET ($TOTAL_VARIANTS variants) into $NUM_BATCHES batches"

        # Split data lines into batches (excluding header)
        tail -n +2 $INPUT_FILE | split -l $BATCH_SIZE - $TMP_DIR/${VARIANT_SET}_batch_

        # Submit a BQP job for each batch
        BATCH_NUM=0
        for BATCH_FILE in $TMP_DIR/${VARIANT_SET}_batch_*; do

            BATCH_NAME=${VARIANT_SET}_batch_${BATCH_NUM}
            BATCH_INPUT=$TMP_DIR/${BATCH_NAME}.txt
            BATCH_OUT=$OUT/$CELL_TYPE/$BATCH_NAME

            # Add header back to batch file
            echo "$HEADER" > $BATCH_INPUT
            cat $BATCH_FILE >> $BATCH_INPUT

            mkdir -p $BATCH_OUT

            echo "Submitting BQP: $CELL_TYPE x $BATCH_NAME"
            echo "n" | python3 $BQP \
                --modelPath "$MODELS/$CELL_TYPE" \
                --inputFile "$BATCH_INPUT" \
                --outputDir "$BATCH_OUT"

            BATCH_NUM=$((BATCH_NUM + 1))
        done

        # Clean up split files (keep the named batch files for reference)
        rm $TMP_DIR/${VARIANT_SET}_batch_a* 2>/dev/null || true

    done
done

echo "All BQP jobs submitted: $(date)"