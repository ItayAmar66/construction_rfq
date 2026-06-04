#!/usr/bin/env bash
# Full catalog emulator gate — native CLI via Flutter test VM (no Chrome).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
EMULATOR_DIR="${EMULATOR_DIR:-/tmp/construction_rfq_emulator}"
CATALOG_DATA_ROOT="${CATALOG_DATA_ROOT:-/Users/itayamar/catalog-working}"
FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8080}"
JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk/jdk-21.0.6+7/Contents/Home}"

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
export CATALOG_DATA_ROOT
export FIRESTORE_EMULATOR_HOST
export CATALOG_IMPORT_OUTPUT="$ROOT/tools/catalog_import/out"

if ! command -v java >/dev/null 2>&1; then
  echo "ERROR: Java required for Firestore emulator."
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "ERROR: Firebase CLI required."
  exit 1
fi

mkdir -p "$EMULATOR_DIR"
cp "$ROOT/firestore.rules" "$EMULATOR_DIR/"
cp "$ROOT/firestore.indexes.json" "$EMULATOR_DIR/"
printf '%s\n' \
  '{' \
  '  "firestore": {' \
  '    "rules": "firestore.rules",' \
  '    "indexes": "firestore.indexes.json"' \
  '  },' \
  '  "emulators": {' \
  '    "firestore": { "port": 8080 },' \
  '    "ui": { "enabled": false }' \
  '  }' \
  '}' > "$EMULATOR_DIR/firebase.json"
printf '%s\n' '{"projects":{"default":"construction-rfq-itay-20-2eee0"}}' > "$EMULATOR_DIR/.firebaserc"

cd "$ROOT"
flutter pub get >/dev/null

echo "=== Catalog emulator gate (native REST CLI) ==="
echo "Dataset: $CATALOG_DATA_ROOT"
echo "Emulator: $FIRESTORE_EMULATOR_HOST"
echo ""
echo "Manual CLI (macOS VM, not Chrome):"
echo "  flutter run -d macos -t tool/catalog_import_main.dart -- --import-full --write --emulator"
echo ""
echo "Running gate test inside firebase emulators:exec ..."
echo ""

START=$(date +%s)
cd "$EMULATOR_DIR"
firebase emulators:exec --only firestore --project construction-rfq-itay-20-2eee0 \
  "cd \"$ROOT\" && flutter test test/catalog_emulator_gate_cli_test.dart -r expanded"
END=$(date +%s)

echo ""
echo "Gate runtime: $((END - START)) seconds"
echo ""
echo "Verification summary:"
if [[ -f "$ROOT/tools/catalog_import/out/emulator_verification/summary.json" ]]; then
  cat "$ROOT/tools/catalog_import/out/emulator_verification/summary.json"
else
  echo "MISSING: tools/catalog_import/out/emulator_verification/summary.json"
  exit 2
fi

echo ""
echo "Gate: PASS"
