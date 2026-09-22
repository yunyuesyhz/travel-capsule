#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/flutterw analyze
./scripts/flutterw test
./scripts/flutterw build apk --release --target-platform android-arm64
