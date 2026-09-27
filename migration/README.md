# Migration Helper Scripts & Guide

This directory contains automated tooling and documentation for migrating **Google Cloud Storage (GCS) buckets** and **BigQuery Datasets/Tables** across GCP projects (e.g. from legacy projects into `permica-ai-vijay` or between environment projects).

## Files in this Folder

- **`migrate_gcs.sh`**: Automated helper script to create target GCS buckets in the destination project and copy/rsync data from source buckets with optional verification.
- **`migrate_bigquery.sh`**: Automated helper script to replicate BigQuery datasets and tables across GCP projects (using direct cross-project copy or GCS export/import fallback).

---

## 1. Quick Start / Prerequisites

Ensure you have authenticated with `gcloud` and have appropriate IAM access to both the source and destination projects:

```bash
# Login to GCP CLI
gcloud auth login
gcloud auth application-default login
```

### Required IAM Roles
- **Source Project**: `roles/storage.objectViewer`, `roles/bigquery.dataViewer`, `roles/bigquery.jobUser`
- **Destination Project (`permica-ai-vijay` / target project)**: `roles/storage.admin`, `roles/bigquery.dataEditor`, `roles/bigquery.jobUser`

---

## 2. GCS Bucket Migration (`migrate_gcs.sh`)

### Usage Syntax
```bash
./migration/migrate_gcs.sh <SOURCE_PROJECT_ID> <DESTINATION_PROJECT_ID> <SOURCE_BUCKET_NAME> <DESTINATION_BUCKET_NAME> [LOCATION]
```

### Example
Migrate bucket `legacy-app-data` to new destination project `permica-ai-vijay-dev-123456`:

```bash
./migration/migrate_gcs.sh \
  legacy-gcp-project-123 \
  permica-ai-vijay-dev-123456 \
  legacy-app-data \
  permica-ai-vijay-dev-app-data \
  us-east1
```

---

## 3. BigQuery Dataset & Table Migration (`migrate_bigquery.sh`)

### Usage Syntax
```bash
./migration/migrate_bigquery.sh <SOURCE_PROJECT_ID> <DESTINATION_PROJECT_ID> <SOURCE_DATASET> <DESTINATION_DATASET> [LOCATION]
```

### Example
Migrate entire dataset `analytics_prod` to destination project `permica-ai-vijay-prod-123456`:

```bash
./migration/migrate_bigquery.sh \
  legacy-gcp-project-123 \
  permica-ai-vijay-prod-123456 \
  analytics_prod \
  analytics_prod \
  US
```
