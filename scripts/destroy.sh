#!/usr/bin/env bash
set -euo pipefail

# Helper script to destroy an entire environment layer (stack infrastructure, GitHub vars, & bootstrap project resources).
# Usage: ./scripts/destroy.sh <env>
# Example: ./scripts/destroy.sh dev
#          ./scripts/destroy.sh prod

TARGET_ENV="${1:-}"

if [ -z "$TARGET_ENV" ]; then
  echo "Usage: $0 <env>" >&2
  echo "Example: $0 dev" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$REPO_ROOT/environments/$TARGET_ENV"
BOOTSTRAP_DIR="$REPO_ROOT/bootstrap"

if [ ! -d "$ENV_DIR" ]; then
  echo "Error: Environment directory not found at $ENV_DIR" >&2
  exit 1
fi

echo "========================================================================="
echo " WARNING: You are about to DESTROY the '$TARGET_ENV' environment."
echo " This will permanently delete Cloud Run, Cloud SQL, Storage Buckets,"
echo " Secret Manager secrets, IAM roles, and the GCP project."
echo "========================================================================="
read -p "Type '$TARGET_ENV' to confirm destruction: " CONFIRM

if [ "$CONFIRM" != "$TARGET_ENV" ]; then
  echo "Destruction cancelled."
  exit 0
fi

# Step 1: Destroy environment application stack resources (Cloud Run, Cloud SQL, etc.)
if [ -f "$ENV_DIR/terraform.tfvars" ]; then
  echo "==> Destroying application stack infrastructure in $ENV_DIR..."
  cd "$BOOTSTRAP_DIR"
  PROJECT_ID=$(terraform output -json github_variables 2>/dev/null | jq -r --arg env "_$(echo "$TARGET_ENV" | tr '[:lower:]' '[:upper:]')" 'to_entries[] | select(.key | endswith($env)) | select(.key | startswith("GCP_PROJECT_ID")) | .value' 2>/dev/null || true)

  cd "$ENV_DIR"
  rm -rf "$ENV_DIR/.terraform"
  if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "null" ]; then
    STATE_BUCKET="${PROJECT_ID}-tfstate"
    # Check if the state bucket actually exists on GCS before attempting backend init
    if gcloud storage buckets describe "gs://${STATE_BUCKET}" &>/dev/null; then
      echo "==> Initializing backend with bucket '${STATE_BUCKET}'..."
      terraform init -reconfigure -input=false -backend-config="bucket=${STATE_BUCKET}" -backend-config="prefix=terraform/state" || true
      terraform destroy -auto-approve -input=false -var-file=terraform.tfvars || true
    else
      echo "==> State bucket '${STATE_BUCKET}' does not exist on GCS (skipping stack destroy)."
    fi
  else
    terraform init -backend=false -reconfigure -input=false || true
  fi

  # Clean up temporary .terraform cache directory, lock file, and state files from environment directory
  rm -rf "$ENV_DIR/.terraform" "$ENV_DIR/.terraform.lock.hcl" "$ENV_DIR/terraform.tfstate" "$ENV_DIR/terraform.tfstate.backup"
fi

# Step 2: Remove GitHub repository variables for this environment
echo "==> Removing GitHub Actions variables for environment '$TARGET_ENV'..."
"$REPO_ROOT/scripts/delete_github_vars.sh" "$TARGET_ENV" || true

# Step 3: Destroy bootstrap resources targeting this environment
if [ -d "$BOOTSTRAP_DIR" ]; then
  echo "==> Destroying bootstrap resources targeting environment '$TARGET_ENV'..."
  cd "$BOOTSTRAP_DIR"

  APP_NAME=$(grep -E '^\s*app_name\s*=' "$BOOTSTRAP_DIR/terraform.tfvars" 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "permica-ai")
  EXISTING_PROJECT=$(gcloud projects list --filter="name=${APP_NAME}-${TARGET_ENV} AND lifecycleState=ACTIVE" --format="value(projectId)" 2>/dev/null | head -n 1 || true)
  
  VAR_ARG=()
  if [ -n "$EXISTING_PROJECT" ]; then
    VAR_ARG=("-var" "${TARGET_ENV}_project_id=${EXISTING_PROJECT}")
    STATE_BUCKET="${EXISTING_PROJECT}-tfstate"
  else
    STATE_BUCKET=$(terraform output -json state_buckets 2>/dev/null | jq -r --arg env "$TARGET_ENV" '.[$env] // empty' 2>/dev/null || true)
  fi

  if [ -n "$STATE_BUCKET" ] && [ "$STATE_BUCKET" != "null" ] && gcloud storage buckets describe "gs://${STATE_BUCKET}" &>/dev/null; then
    cat <<EOF > "$BOOTSTRAP_DIR/backend.tf"
terraform {
  backend "gcs" {}
}
EOF
    terraform init -reconfigure -force-copy -input=false -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=bootstrap/state" || true
    terraform state pull > "$BOOTSTRAP_DIR/terraform.tfstate" 2>/dev/null || true
    rm -f "$BOOTSTRAP_DIR/backend.tf"
    rm -rf "$BOOTSTRAP_DIR/.terraform" "$BOOTSTRAP_DIR/.terraform.lock.hcl"
    terraform init -reconfigure -input=false || true
  else
    rm -f "$BOOTSTRAP_DIR/backend.tf"
    rm -rf "$BOOTSTRAP_DIR/.terraform" "$BOOTSTRAP_DIR/.terraform.lock.hcl"
    terraform init -reconfigure -input=false || true
  fi


  if [ -n "${EXISTING_PROJECT:-}" ]; then
    echo "==> Importing active bootstrap resources for '$EXISTING_PROJECT' into state..."
    terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_project.env[\"${TARGET_ENV}\"]" "$EXISTING_PROJECT" 2>/dev/null || true
    terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_storage_bucket.state[\"${TARGET_ENV}\"]" "${EXISTING_PROJECT}/${EXISTING_PROJECT}-tfstate" 2>/dev/null || true
    terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_service_account.apply[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/serviceAccounts/tf-apply@${EXISTING_PROJECT}.iam.gserviceaccount.com" 2>/dev/null || true
    terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_service_account.plan[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/serviceAccounts/tf-plan@${EXISTING_PROJECT}.iam.gserviceaccount.com" 2>/dev/null || true
    terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_iam_workload_identity_pool.github[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/locations/global/workloadIdentityPools/github" 2>/dev/null || true
    terraform import ${VAR_ARG+"${VAR_ARG[@]}"} "google_iam_workload_identity_pool_provider.github[\"${TARGET_ENV}\"]" "projects/${EXISTING_PROJECT}/locations/global/workloadIdentityPools/github/providers/github" 2>/dev/null || true
  fi



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

  terraform destroy -auto-approve ${VAR_ARG+"${VAR_ARG[@]}"} "${TARGET_ARGS[@]}" || true

  # Cleanup temporary files, lock files, and local backend state
  rm -rf "$BOOTSTRAP_DIR/.terraform" "$BOOTSTRAP_DIR/.terraform.lock.hcl" "$BOOTSTRAP_DIR/backend.tf" "$BOOTSTRAP_DIR/terraform.tfstate" "$BOOTSTRAP_DIR/terraform.tfstate.backup"
fi

echo "==> Environment '$TARGET_ENV' destroyed successfully!"
