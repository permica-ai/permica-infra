#!/usr/bin/env bash
set -euo pipefail

# Helper script to set GitHub Actions repository variables for application repositories (e.g., permica-core).
# Usage: ./scripts/update_app_github_vars.sh <target-repo> [env]

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <target-repo> [env: dev|prod]" >&2
  echo "Example: $0 permica-ai/permica-core dev" >&2
  exit 1
fi

TARGET_REPO="$1"
TARGET_ENV="${2:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v gh &> /dev/null; then
  echo "Error: 'gh' (GitHub CLI) is required. Please install it first." >&2
  exit 1
fi

set_var_for_env() {
  local env_name="$1"
  local env_dir="$REPO_ROOT/environments/$env_name"
  local env_upper="$(echo "$env_name" | tr '[:lower:]' '[:upper:]')"

  if [ ! -d "$env_dir" ]; then
    echo "Error: Environment directory not found at $env_dir" >&2
    return 1
  fi

  echo "==> Fetching terraform outputs for environment '$env_name'..."
  (
    cd "$env_dir"

    # Fetch project ID from GitHub repo variables first, falling back to local terraform.tfvars
    INFRA_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "permica-ai/permica-infra")"
    PROJ_ID="$(gh variable get "GCP_PROJECT_ID_${env_upper}" --repo "$INFRA_REPO" 2>/dev/null || true)"
    if [ -z "$PROJ_ID" ]; then
      PROJ_ID=$(grep -E '^\s*project_id\s*=' "$env_dir/terraform.tfvars" 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || true)
    fi

    if [ -z "$PROJ_ID" ]; then
      echo "Error: Unable to determine GCP Project ID for environment '$env_name'." >&2
      exit 1
    fi

    STATE_BUCKET="${PROJ_ID}-tfstate"

    cat <<EOT > "$env_dir/backend.tf"
terraform {
  backend "gcs" {}
}
EOT
    rm -rf "$env_dir/.terraform" "$env_dir/.terraform.lock.hcl"
    terraform init -input=false -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=terraform/state" > /dev/null 2>&1 || true

    if ! terraform output -json app_deploy_github_variables > /dev/null 2>&1; then
      echo "Error: Failed to read 'app_deploy_github_variables' output in $env_dir." >&2
      echo "Ensure 'terraform apply' has been run for $env_name." >&2
      rm -rf "$env_dir/.terraform" "$env_dir/.terraform.lock.hcl"
      exit 1
    fi

    echo "==> Setting GitHub repository variables on '${TARGET_REPO}' for environment suffix '_${env_upper}'..."
    terraform output -json app_deploy_github_variables | jq -r --arg env "_${env_upper}" 'to_entries[] | "\(.key)\($env)=\(.value)"' | while IFS='=' read -r key val; do
      echo "Setting variable: ${key} on repo ${TARGET_REPO}"
      gh variable set "$key" --body "$val" --repo "$TARGET_REPO"
    done

    # Clean up local workspace artifacts after reading outputs
    rm -rf "$env_dir/.terraform" "$env_dir/.terraform.lock.hcl"
  )
}

if [ -n "$TARGET_ENV" ]; then
  set_var_for_env "$TARGET_ENV"
else
  set_var_for_env "dev"
  if [ -d "$REPO_ROOT/environments/prod" ]; then
    set_var_for_env "$REPO_ROOT/environments/prod"
  fi
fi

echo "==> Successfully updated app repository variables for ${TARGET_REPO}!"
