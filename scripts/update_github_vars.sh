#!/usr/bin/env bash
set -euo pipefail

# Helper script to set GitHub Actions repository variables.
# Usage: ./scripts/update_github_vars.sh [env]
# Example: ./scripts/update_github_vars.sh staging   # updates only GCP_*_STAGING variables
#          ./scripts/update_github_vars.sh           # updates all variables from bootstrap outputs

TARGET_ENV="${1:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="$REPO_ROOT/bootstrap"

if [ ! -d "$BOOTSTRAP_DIR" ]; then
  echo "Error: bootstrap directory not found at $BOOTSTRAP_DIR" >&2
  exit 1
fi

cd "$BOOTSTRAP_DIR"

# Ensure Terraform backend is initialized if backend.tf is missing
if [ ! -f "$BOOTSTRAP_DIR/backend.tf" ]; then
  APP_NAME=$(grep -E '^\s*app_name\s*=' "$BOOTSTRAP_DIR/terraform.tfvars" 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo "permica-ai")
  EXISTING_PROJECT=$(gcloud projects list --filter="name=${APP_NAME}-dev AND lifecycleState=ACTIVE" --format="value(projectId)" 2>/dev/null | head -n 1 || true)
  if [ -n "$EXISTING_PROJECT" ]; then
    STATE_BUCKET="${EXISTING_PROJECT}-tfstate"
    cat <<EOF > "$BOOTSTRAP_DIR/backend.tf"
terraform {
  backend "gcs" {}
}
EOF
    terraform init -reconfigure -input=false -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=bootstrap/state" > /dev/null 2>&1
  fi
fi

echo "==> Fetching terraform outputs from $BOOTSTRAP_DIR..."
if ! terraform output -json github_variables > /dev/null 2>&1; then
  echo "Error: Failed to read terraform output 'github_variables'. Ensure 'terraform apply' has been run in bootstrap/." >&2
  exit 1
fi

if [ -n "$TARGET_ENV" ]; then
  ENV_UPPER="$(echo "$TARGET_ENV" | tr '[:lower:]' '[:upper:]')"
  echo "==> Setting GitHub repository variables for environment '$TARGET_ENV' (${ENV_UPPER})..."
  terraform output -json github_variables | jq -r --arg env "_${ENV_UPPER}" 'to_entries[] | select(.key | endswith($env)) | "\(.key)=\(.value)"' | while IFS='=' read -r key val; do
    echo "Setting variable: $key"
    gh variable set "$key" --body "$val"
  done
else
  echo "==> Setting ALL GitHub repository variables via gh CLI..."
  terraform output -json github_variables | jq -r 'to_entries[] | "\(.key)=\(.value)"' | while IFS='=' read -r key val; do
    echo "Setting variable: $key"
    gh variable set "$key" --body "$val"
  done
fi

echo "==> Successfully updated GitHub repository variables!"

