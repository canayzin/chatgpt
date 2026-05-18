#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-development}"
CONFIG_FILE="config/env/${ENVIRONMENT}.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Environment file not found: $CONFIG_FILE"
  exit 2
fi

required_keys=(appEnv firebaseProjectId apiBaseUrl enableCrashlytics enablePerformanceMonitoring)
for key in "${required_keys[@]}"; do
  if ! jq -e ".${key}" "$CONFIG_FILE" >/dev/null; then
    echo "Missing key '${key}' in ${CONFIG_FILE}"
    exit 3
  fi
done

echo "Environment config verified: ${CONFIG_FILE}"
