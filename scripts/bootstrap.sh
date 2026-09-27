#!/usr/bin/env bash
set -euo pipefail

# Helper script to run bootstrap terraform apply for a specific environment or all environments.
# Usage: ./scripts/bootstrap.sh [env]
# Examples:
#   ./scripts/bootstrap.sh dev      # Provision bootstrap resources for dev only
#   ./scripts/bootstrap.sh prod     # Provision bootstrap resources for prod only
#   ./scripts/bootstrap.sh          # Provision bootstrap resources for all environments

TARGET_ENV="${1:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="$REPO_ROOT/bootstrap"

if [ ! -d "$BOOTSTRAP_DIR" ]; then
  echo "Error: bootstrap directory not found at $BOOTSTRAP_DIR" >&2
  exit 1
fi

cd "$BOOTSTRAP_DIR"

# Check if an active GCP project already exists for this app and environment
APP_NAME=$(grep -E '^\s*app_name\s*=' "$BOOTSTRAP_DIR/terraform.tfvars" 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "permica-ai")

VAR_ARG=()

if [ -n "$TARGET_ENV" ]; then
  EXISTING_PROJECT=$(gcloud projects list --filter="name=${APP_NAME}-${TARGET_ENV} AND lifecycleState=ACTIVE" --format="value(projectId)" 2>/dev/null | head -n 1 || true)
  if [ -n "$EXISTING_PROJECT" ]; then
    echo "==> Found existing active GCP project: '$EXISTING_PROJECT'"
    VAR_ARG=("-var" "${TARGET_ENV}_project_id=${EXISTING_PROJECT}")
    STATE_BUCKET="${EXISTING_PROJECT}-tfstate"
  fi
fi

if [ -n "${STATE_BUCKET:-}" ] && gcloud storage buckets describe "gs://${STATE_BUCKET}" &>/dev/null; then
  echo "==> Initializing backend with GCS bucket '$STATE_BUCKET'..."
  cat <<EOF > "$BOOTSTRAP_DIR/backend.tf"
terraform {
  backend "gcs" {}
}
EOF
  terraform init -reconfigure -force-copy -input=false -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=bootstrap/state"
else
  echo "==> Initializing local Terraform workspace..."
  rm -f "$BOOTSTRAP_DIR/backend.tf"
  terraform init -backend=false -reconfigure -input=false
fi

if [ -n "${EXISTING_PROJECT:-}" ]; then
  echo "==> Ensuring existing GCP bootstrap resources for '$EXISTING_PROJECT' are present in state..."
  terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_project.env[\"${TARGET_ENV}\"]" "$EXISTING_PROJECT" 2>/dev/null || true
  terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_storage_bucket.state[\"${TARGET_ENV}\"]" "${EXISTING_PROJECT}/${EXISTING_PROJECT}-tfstate" 2>/dev/null || true
  terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_service_account.apply[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/serviceAccounts/tf-apply@${EXISTING_PROJECT}.iam.gserviceaccount.com" 2>/dev/null || true
  terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_service_account.plan[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/serviceAccounts/tf-plan@${EXISTING_PROJECT}.iam.gserviceaccount.com" 2>/dev/null || true
  terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_iam_workload_identity_pool.github[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/locations/global/workloadIdentityPools/github" 2>/dev/null || true
  terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_iam_workload_identity_pool_provider.github[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/locations/global/workloadIdentityPools/github/providers/github" 2>/dev/null || true
fi

if [ -n "$TARGET_ENV" ]; then
  echo "==> Running bootstrap terraform apply targeting environment '$TARGET_ENV'..."
  
  APIS=(
    "cloudresourcemanager.googleapis.com"
    "serviceusage.googleapis.com"
    "iam.googleapis.com"
    "iamcredentials.googleapis.com"
    "sts.googleapis.com"
    "storage.googleapis.com"
  )

  PLAN_ROLES=(
    "roles/viewer"
    "roles/iam.securityReviewer"
    "roles/secretmanager.secretAccessor"
  )

  TARGET_ARGS=(
    "-target=google_project.env[\"${TARGET_ENV}\"]"
    "-target=google_storage_bucket.state[\"${TARGET_ENV}\"]"
    "-target=google_service_account.apply[\"${TARGET_ENV}\"]"
    "-target=google_service_account.plan[\"${TARGET_ENV}\"]"
    "-target=google_project_iam_member.apply_owner[\"${TARGET_ENV}\"]"
    "-target=google_storage_bucket_iam_member.plan_state[\"${TARGET_ENV}\"]"
    "-target=google_iam_workload_identity_pool.github[\"${TARGET_ENV}\"]"
    "-target=google_iam_workload_identity_pool_provider.github[\"${TARGET_ENV}\"]"
    "-target=google_service_account_iam_member.apply_wif[\"${TARGET_ENV}\"]"
    "-target=google_service_account_iam_member.plan_wif[\"${TARGET_ENV}\"]"
  )

  for api in "${APIS[@]}"; do
    TARGET_ARGS+=("-target=google_project_service.bootstrap[\"${TARGET_ENV}/${api}\"]")
  done

  for role in "${PLAN_ROLES[@]}"; do
    TARGET_ARGS+=("-target=google_project_iam_member.plan[\"${TARGET_ENV}/${role}\"]")
  done

  terraform apply -auto-approve ${VAR_ARG+"${VAR_ARG[@]}"} "${TARGET_ARGS[@]}"
else
  echo "==> Running bootstrap terraform apply for ALL environments..."
  terraform apply -auto-approve ${VAR_ARG+"${VAR_ARG[@]}"}
fi

# Migrate state to GCS bucket if backend.tf was not configured prior to apply
STATE_BUCKET=$(terraform output -json state_buckets 2>/dev/null | jq -r 'to_entries[0].value // empty')

if [ ! -f "$BOOTSTRAP_DIR/backend.tf" ] && [ -n "$STATE_BUCKET" ] && [ "$STATE_BUCKET" != "null" ]; then
  echo "==> Migrating bootstrap state to GCS bucket '$STATE_BUCKET'..."
  cat <<EOF > "$BOOTSTRAP_DIR/backend.tf"
terraform {
  backend "gcs" {}
}
EOF
  terraform init -force-copy -input=false -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=bootstrap/state"
  echo "==> Bootstrap state successfully migrated to GCS bucket '$STATE_BUCKET'!"
fi

echo "==> Updating GitHub repository variables..."
"$REPO_ROOT/scripts/update_github_vars.sh" "$TARGET_ENV"

# Clean up local temporary state and backend configuration
rm -f "$BOOTSTRAP_DIR/backend.tf" "$BOOTSTRAP_DIR/terraform.tfstate" "$BOOTSTRAP_DIR/terraform.tfstate.backup"
rm -rf "$BOOTSTRAP_DIR/.terraform"

echo "==> Bootstrap completed successfully!"
