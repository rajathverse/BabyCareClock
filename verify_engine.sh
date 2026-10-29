#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="${TMPDIR:-/tmp}/childcareclock-engine-smoke-test"
swiftc \
  "$ROOT/Shared/CareModels.swift" \
  "$ROOT/Shared/CareEngine.swift" \
  "$ROOT/Shared/CarePersistence.swift" \
  "$ROOT/Shared/AppLanguage.swift" \
  "$ROOT/Shared/Vaccines.swift" \
  "$ROOT/Verification/EngineSmokeTest.swift" \
  -o "$OUTPUT"
"$OUTPUT"
