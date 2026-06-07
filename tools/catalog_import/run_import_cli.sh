#!/usr/bin/env bash
# Catalog import CLI via Flutter test VM — no macOS app sandbox (reliable file access).
#
# Usage:
#   ./tools/catalog_import/run_import_cli.sh --import-full --full-dry-run --production \
#     --project=construction-rfq-itay-20-2eee0
#
# Env: CATALOG_DATA_ROOT, FIRESTORE_EMULATOR_HOST, CATALOG_IMPORT_OUTPUT, GOOGLE_APPLICATION_CREDENTIALS

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <catalog-import-args...>" >&2
  echo "Example: $0 --import-full --full-dry-run --production --project=construction-rfq-itay-20-2eee0" >&2
  exit 1
fi

export CATALOG_IMPORT_CLI_ARGS="$*"

flutter test test/catalog_import_runner_test.dart --plain-name "catalog import CLI runner"
