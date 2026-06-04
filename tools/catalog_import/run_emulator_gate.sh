#!/usr/bin/env bash
# Full catalog emulator import + verification gate (Phase 3.5)
# Run from macOS Terminal (outside Cursor) if socket bind fails in IDE agents.
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

if ! command -v java >/dev/null 2>&1 || ! java -version 2>&1 | grep -q "21"; then
  echo "ERROR: Java 21 required. Install:"
  echo "  brew install openjdk@21"
  echo "  export JAVA_HOME=\$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
  echo "Or extract Temurin 21 to ~/.local/jdk (see CATALOG_EMULATOR_IMPORT_REPORT.md)"
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "ERROR: Firebase CLI required. Install: npm install -g firebase-tools"
  exit 1
fi

mkdir -p "$EMULATOR_DIR"
cp "$ROOT/firestore.rules" "$EMULATOR_DIR/"
cp "$ROOT/firestore.indexes.json" "$EMULATOR_DIR/"
cat > "$EMULATOR_DIR/firebase.json" <<'EOF'
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "emulators": {
    "firestore": { "port": 8080 },
    "ui": { "enabled": false }
  }
}
EOF
echo '{"projects":{"default":"construction-rfq-itay-20-2eee0"}}' > "$EMULATOR_DIR/.firebaserc"

cd "$ROOT"
echo "=== Gate: rollback (clean) + full import + verify ==="
echo "Emulator dir: $EMULATOR_DIR"
echo "Dataset: $CATALOG_DATA_ROOT"
echo "FIRESTORE_EMULATOR_HOST=$FIRESTORE_EMULATOR_HOST"
echo ""
echo "Starting Firestore emulator and running integration test..."
echo "(Keep this terminal open; emulator runs inside firebase emulators:exec)"
echo ""

START=$(date +%s)
cd "$EMULATOR_DIR"
firebase emulators:exec --only firestore --project construction-rfq-itay-20-2eee0 \
  "cd \"$ROOT\" && flutter test test/catalog_emulator_integration_test.dart -r expanded"
END=$(date +%s)

echo ""
echo "Runtime: $((END - START)) seconds"
echo "Verification summary:"
if [[ -f "$ROOT/tools/catalog_import/out/emulator_verification/summary.json" ]]; then
  cat "$ROOT/tools/catalog_import/out/emulator_verification/summary.json"
else
  echo "MISSING: tools/catalog_import/out/emulator_verification/summary.json"
  exit 2
fi

echo ""
echo "Gate complete. Update CATALOG_EMULATOR_IMPORT_REPORT.md with results if needed."
