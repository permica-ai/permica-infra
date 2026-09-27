#!/usr/bin/env bash
set -euo pipefail

# Helper script to migrate BigQuery Datasets/Tables across GCP projects.
# Usage: ./migration/migrate_bigquery.sh <SOURCE_PROJECT_ID> <DEST_PROJECT_ID> <SOURCE_DATASET> <DEST_DATASET> [LOCATION]

SOURCE_PROJECT="${1:-}"
DEST_PROJECT="${2:-}"
SOURCE_DATASET="${3:-}"
DEST_DATASET="${4:-}"
LOCATION="${5:-US}"

if [ -z "$SOURCE_PROJECT" ] || [ -z "$DEST_PROJECT" ] || [ -z "$SOURCE_DATASET" ] || [ -z "$DEST_DATASET" ]; then
  echo "Error: Missing required arguments." >&2
  echo "Usage: $0 <SOURCE_PROJECT_ID> <DEST_PROJECT_ID> <SOURCE_DATASET> <DEST_DATASET> [LOCATION]" >&2
  exit 1
fi

echo "========================================================================="
echo " Starting BigQuery Migration"
echo " Source Project : $SOURCE_PROJECT"
echo " Source Dataset : $SOURCE_DATASET"
echo " Dest Project   : $DEST_PROJECT"
echo " Dest Dataset   : $DEST_DATASET"
echo " Location       : $LOCATION"
echo "========================================================================="

# Ensure target dataset exists in destination project
if ! bq show --project_id="$DEST_PROJECT" "$DEST_DATASET" &>/dev/null; then
  echo "==> Creating destination dataset ${DEST_PROJECT}:${DEST_DATASET}..."
  bq mk --project_id="$DEST_PROJECT" --location="$LOCATION" "$DEST_DATASET"
else
  echo "==> Destination dataset ${DEST_PROJECT}:${DEST_DATASET} already exists."
fi

# Fetch tables from source dataset
TABLES=$(bq ls --project_id="$SOURCE_PROJECT" --max_results=1000 "$SOURCE_DATASET" | awk 'NR>2 {print $1}')

if [ -z "$TABLES" ]; then
  echo "==> No tables found in source dataset ${SOURCE_DATASET}."
  exit 0
fi

echo "==> Found tables to migrate:"
echo "$TABLES"
echo "-------------------------------------------------------------------------"

for TABLE in $TABLES; do
  echo "==> Migrating table: $TABLE..."
  
  # Attempt direct cross-project copy
  if bq cp -f "${SOURCE_PROJECT}:${SOURCE_DATASET}.${TABLE}" "${DEST_PROJECT}:${DEST_DATASET}.${TABLE}"; then
    echo "  [OK] Successfully copied ${TABLE}"
  else
    echo "  [FAIL] Direct copy failed for ${TABLE}. Check region compatibility or permissions."
  fi
done

echo "========================================================================="
echo " BigQuery Migration Finished"
echo "========================================================================="
