#!/usr/bin/env bash
set -euo pipefail

# Helper script to set GitHub Actions repository variables for application repositories (e.g., permica-core, permica-basis-explorer).
# Usage: ./scripts/update_app_github_vars.sh <target-repo> [env]
# Example: ./scripts/update_app_github_vars.sh permica-ai/permica-core dev

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

# Clean up stale local terraform cache and lock files across environments before reading outputs
clean_local_cache() {
  echo "==> Cleaning local Terraform cache & lock files..."
  rm -rf "$REPO_ROOT/environments/shared/.terraform" "$REPO_ROOT/environments/shared/.terraform.lock.hcl" 2>/dev/null || true
  rm -rf "$REPO_ROOT/environments/dev/.terraform" "$REPO_ROOT/environments/dev/.terraform.lock.hcl" 2>/dev/null || true
  rm -rf "$REPO_ROOT/environments/prod/.terraform" "$REPO_ROOT/environments/prod/.terraform.lock.hcl" 2>/dev/null || true
}

clean_local_cache

# Fetch and sync shared Cloud SQL connection parameters if shared environment is provisioned
sync_shared_cloud_sql() {
  local shared_dir="$REPO_ROOT/environments/shared"
  if [ ! -d "$shared_dir" ]; then
    return 0
  fi

  INFRA_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "permica-ai/permica-infra")"
  SHARED_PROJ_ID="$(gh variable get "GCP_PROJECT_ID_SHARED" --repo "$INFRA_REPO" 2>/dev/null || true)"
  if [ -z "$SHARED_PROJ_ID" ]; then
    SHARED_PROJ_ID=$(grep -E '^\s*project_id\s*=' "$shared_dir/terraform.tfvars" 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || true)
  fi

  if [ -n "$SHARED_PROJ_ID" ]; then
    STATE_BUCKET="${SHARED_PROJ_ID}-tfstate"
    echo "==> Checking shared Cloud SQL outputs from '$SHARED_PROJ_ID'..."
    (
      cd "$shared_dir"
      cat <<EOT > "$shared_dir/backend.tf"
terraform {
  backend "gcs" {}
}
EOT
      rm -rf "$shared_dir/.terraform" "$shared_dir/.terraform.lock.hcl"
      if terraform init -input=false -backend-config="bucket=$STATE_BUCKET" -backend-config="prefix=terraform/state" > /dev/null 2>&1; then
        CONN_NAME=$(terraform output -raw connection_name 2>/dev/null || true)
        if [ -n "$CONN_NAME" ] && [ "$CONN_NAME" != "null" ]; then
          echo "==> Found shared Cloud SQL connection: '$CONN_NAME'"
          for e in dev prod; do
            local tfvars="$REPO_ROOT/environments/$e/terraform.tfvars"
            if [ -f "$tfvars" ]; then
              echo "==> Updating $tfvars with shared_cloud_sql_connection_name..."
              sed -i '' "s|^\s*shared_cloud_sql_connection_name\s*=.*|shared_cloud_sql_connection_name = \"$CONN_NAME\"|" "$tfvars" 2>/dev/null || \
              sed -i "s|^\s*shared_cloud_sql_connection_name\s*=.*|shared_cloud_sql_connection_name = \"$CONN_NAME\"|" "$tfvars" 2>/dev/null || \
              echo "shared_cloud_sql_connection_name = \"$CONN_NAME\"" >> "$tfvars"
            fi
          done

          echo "==> Setting shared Cloud SQL GitHub variables on '${TARGET_REPO}'..."
          gh variable set "GCP_SHARED_CLOUD_SQL_CONNECTION_NAME" --body "$CONN_NAME" --repo "$TARGET_REPO" 2>/dev/null || true
          gh variable set "GCP_SHARED_DB_NAME" --body "permica-gis" --repo "$TARGET_REPO" 2>/dev/null || true
        fi
      fi
      rm -rf "$shared_dir/.terraform" "$shared_dir/.terraform.lock.hcl"
    )
  fi
}

sync_shared_cloud_sql

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
    JSON_VARS=$(terraform output -json app_deploy_github_variables)
    for key in $(echo "$JSON_VARS" | jq -r 'keys[]'); do
      val=$(echo "$JSON_VARS" | jq -r --arg k "$key" '.[$k]')
      if [ -n "$val" ] && [ "$val" != "null" ]; then
        target_key="${key}_${env_upper}"
        echo "Setting variable: ${target_key} on repo ${TARGET_REPO}"
        gh variable set "$target_key" --body "$val" --repo "$TARGET_REPO"
      fi
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
    set_var_for_env "prod"
  fi
fi

echo "==> Successfully updated app repository variables for ${TARGET_REPO}!"
