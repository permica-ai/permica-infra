#!/usr/bin/env bash
set -euo pipefail

# Helper script to migrate GCS bucket contents between GCP projects.
# Usage: ./migration/migrate_gcs.sh <SOURCE_PROJECT_ID> <DEST_PROJECT_ID> <SOURCE_BUCKET> <DEST_BUCKET> [LOCATION]

SOURCE_PROJECT="${1:-}"
DEST_PROJECT="${2:-}"
SOURCE_BUCKET="${3:-}"
DEST_BUCKET="${4:-}"
LOCATION="${5:-us-central1}"

if [ -z "$SOURCE_PROJECT" ] || [ -z "$DEST_PROJECT" ] || [ -z "$SOURCE_BUCKET" ] || [ -z "$DEST_BUCKET" ]; then
  echo "Error: Missing required arguments." >&2
  echo "Usage: $0 <SOURCE_PROJECT_ID> <DEST_PROJECT_ID> <SOURCE_BUCKET> <DEST_BUCKET> [LOCATION]" >&2
  exit 1
fi

echo "========================================================================="
echo " Starting GCS Migration"
echo " Source Project : $SOURCE_PROJECT"
echo " Source Bucket  : gs://$SOURCE_BUCKET"
echo " Dest Project   : $DEST_PROJECT"
echo " Dest Bucket    : gs://$DEST_BUCKET"
echo " Location       : $LOCATION"
echo "========================================================================="

# Check if destination bucket exists, create if missing
if ! gcloud storage buckets describe "gs://${DEST_BUCKET}" --project="$DEST_PROJECT" &>/dev/null; then
  echo "==> Creating target bucket gs://${DEST_BUCKET} in project ${DEST_PROJECT}..."
  gcloud storage buckets create "gs://${DEST_BUCKET}" \
    --project="$DEST_PROJECT" \
    --location="$LOCATION" \
    --uniform-bucket-level-access
else
  echo "==> Target bucket gs://${DEST_BUCKET} already exists."
fi

echo "==> Syncing objects from gs://${SOURCE_BUCKET} to gs://${DEST_BUCKET}..."
gcloud storage rsync -r "gs://${SOURCE_BUCKET}" "gs://${DEST_BUCKET}"

echo "==> Validating object counts..."
SRC_COUNT=$(gcloud storage ls --recursive "gs://${SOURCE_BUCKET}" 2>/dev/null | wc -l | tr -d ' ')
DEST_COUNT=$(gcloud storage ls --recursive "gs://${DEST_BUCKET}" 2>/dev/null | wc -l | tr -d ' ')

echo "Source object count: $SRC_COUNT"
echo "Dest object count  : $DEST_COUNT"

if [ "$SRC_COUNT" -eq "$DEST_COUNT" ]; then
  echo "==> SUCCESS: Object counts match perfectly."
else
  echo "==> WARNING: Object count mismatch ($SRC_COUNT source vs $DEST_COUNT dest). Check for hidden files or failed transfers."
fi
