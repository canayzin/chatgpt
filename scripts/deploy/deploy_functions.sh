#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"

if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "development" ]]; then
  echo "Unsupported environment: $ENVIRONMENT"
  exit 2
fi

PROJECT_ID=$(jq -r '.firebaseProjectId' "config/env/${ENVIRONMENT}.json")

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "null" ]]; then
  echo "Missing firebaseProjectId in config/env/${ENVIRONMENT}.json"
  exit 3
fi

echo "Deploying Firebase functions to ${PROJECT_ID} (${ENVIRONMENT})"

# Deploy only functions to reduce blast radius.
firebase deploy --project "$PROJECT_ID" --only functions

echo "Functions deployed successfully"
