#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-staging}"

if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "development" ]]; then
  echo "Unsupported environment: $ENVIRONMENT"
  exit 2
fi

if ! command -v flutter >/dev/null; then
  echo "Flutter SDK is required"
  exit 3
fi

CONFIG_FILE="config/env/${ENVIRONMENT}.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing env config: $CONFIG_FILE"
  exit 4
fi

flutter pub get
flutter test
flutter build appbundle --release --dart-define-from-file="$CONFIG_FILE"

echo "AAB generated at build/app/outputs/bundle/release/"
