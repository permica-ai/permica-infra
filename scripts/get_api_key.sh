#!/usr/bin/env bash
set -euo pipefail

# Helper script to fetch the active API Gateway Key string for an environment (dev/prod).
# Usage: ./scripts/get_api_key.sh <env> [project-id]
# Example: ./scripts/get_api_key.sh dev
# Example: ./scripts/get_api_key.sh dev permica-ai-dev-259031

ENV="${1:-dev}"
PROJECT_ID="${2:-}"

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Error: Environment must be 'dev' or 'prod'." >&2
  echo "Usage: $0 <dev|prod> [project-id]" >&2
  exit 1
fi

# Auto-derive project ID from environment if not provided
if [[ -z "$PROJECT_ID" ]]; then
  ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../environments/${ENV}" && pwd)"
  if [[ -f "${ENV_DIR}/terraform.tfvars" ]]; then
    PROJECT_ID=$(grep -E '^\s*project_id\s*=' "${ENV_DIR}/terraform.tfvars" | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "' | tr -d "'")
  fi
fi

if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: Could not determine project_id for environment '${ENV}'." >&2
  echo "Usage: $0 <dev|prod> <project-id>" >&2
  exit 1
fi

KEY_NAME="permica-ai-${ENV}-key"

echo "==> Fetching API key '${KEY_NAME}' from project '${PROJECT_ID}'..." >&2

# Get resource key path
KEY_PATH=$(gcloud services api-keys list --project="${PROJECT_ID}" --filter="displayName ~ '${ENV}' OR name ~ '${KEY_NAME}'" --format="value(name)" | head -n 1)

if [[ -z "$KEY_PATH" ]]; then
  echo "Error: API key '${KEY_NAME}' not found in project '${PROJECT_ID}'." >&2
  exit 1
fi

# Fetch key string
KEY_STRING=$(gcloud services api-keys get-key-string "${KEY_PATH}" --project="${PROJECT_ID}" --format="value(keyString)")

echo "${KEY_STRING}"
