#!/usr/bin/env bash
# =============================================================================
# DEV ONLY — wrapper to reset Firestore MVP data (see tool/RESET_FIRESTORE_DEV.md)
# NOT for production. Does not run automatically.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo ""
echo "⚠️  DEV ONLY: This will delete Firestore app data in your configured Firebase project."
echo "    Read: tool/RESET_FIRESTORE_DEV.md"
echo ""

DEVICE="${1:-chrome}"
EXTRA_ARGS=("${@:2}")

flutter pub get
flutter run -t lib/dev/reset_firestore_dev_main.dart -d "$DEVICE" -- --confirm "${EXTRA_ARGS[@]}"
