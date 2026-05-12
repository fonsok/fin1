#!/usr/bin/env bash
# Local Parse-shaped API smoke (127.0.0.1 only). See .github/workflows/ci.yml.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec node "$ROOT/scripts/ci-smoke-local-mock.mjs"
