#!/usr/bin/env bash
set -euo pipefail

# Helper script to set GitHub Actions repository variables for application repositories (e.g., permica-core).
# Usage: ./scripts/update_app_github_vars.sh <target-repo> [env]
# Examples:
#   ./scripts/update_app_github_vars.sh Vijay-E-Permica/permica-core dev
#   ./scripts/update_app_github_vars.sh Vijay-E-Permica/permica-core prod
#   ./scripts/update_app_github_vars.sh Vijay-E-Permica/permica-core      # updates variables for dev and prod

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <target-repo> [env: dev|prod]" >&2
  echo "Example: $0 Vijay-E-Permica/permica-core dev" >&2
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
    if ! terraform output -json app_deploy_github_variables > /dev/null 2>&1; then
      echo "Error: Failed to read 'app_deploy_github_variables' output in $env_dir." >&2
      echo "Ensure 'terraform apply' has been run for $env_name." >&2
      exit 1
    fi

    echo "==> Setting GitHub repository variables on '${TARGET_REPO}' for environment suffix '_${env_upper}'..."
    terraform output -json app_deploy_github_variables | jq -r --arg env "_${env_upper}" 'to_entries[] | "\(.key)\($env)=\(.value)"' | while IFS='=' read -r key val; do
      echo "Setting variable: ${key} on repo ${TARGET_REPO}"
      gh variable set "$key" --body "$val" --repo "$TARGET_REPO"
    done
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
