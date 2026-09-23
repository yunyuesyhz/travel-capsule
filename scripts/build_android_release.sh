#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$ROOT/pubspec.yaml"
KEYSTORE="$ROOT/.tooling/signing/current-release.keystore"
ARTIFACTS="$ROOT/artifacts"
BUILD_TOOLS="$ROOT/.tooling/android-sdk/build-tools/36.0.0"

if [[ ! -f "$KEYSTORE" ]]; then
  echo "Missing persistent signing key: $KEYSTORE" >&2
  echo "Restore the private .tooling/signing/current-release.keystore backup before building updates." >&2
  exit 1
fi

VERSION="$(sed -n 's/^version:[[:space:]]*//p' "$PUBSPEC" | head -n 1)"
VERSION_NAME="${VERSION%%+*}"
ARTIFACT_NAME="trail-capsule-${VERSION_NAME}-arm64.apk"

export XDG_CONFIG_HOME="$ROOT/.tooling/xdg-config"
export FLUTTER_SUPPRESS_ANALYTICS=true

# Flutter 3.47 can leave the dev-only integration_test plugin in this ignored
# generated Java file when building with --no-pub. Keep it out of release Java
# compilation, then restore the generated file even if Gradle fails.
REGISTRANT="$ROOT/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
REGISTRANT_BACKUP=""
if [[ -f "$REGISTRANT" ]] && grep -q 'dev.flutter.plugins.integration_test.IntegrationTestPlugin' "$REGISTRANT"; then
  REGISTRANT_BACKUP="$(mktemp)"
  cp "$REGISTRANT" "$REGISTRANT_BACKUP"
  restore_registrant() {
    cp "$REGISTRANT_BACKUP" "$REGISTRANT"
    rm -f "$REGISTRANT_BACKUP"
  }
  trap restore_registrant EXIT
  python3 - "$REGISTRANT" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
contents = path.read_text()
pattern = (
    r"    try \{\n"
    r"      flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\n"
    r"    \} catch \(Exception e\) \{\n"
    r"      Log\.e\(TAG, \"Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\", e\);\n"
    r"    \}\n"
)
contents, count = re.subn(pattern, "", contents)
if count != 1:
    raise SystemExit(f"Expected one generated integration_test registration, found {count}")
path.write_text(contents)
PY
fi

"$ROOT/scripts/flutterw" build apk --release --target-platform android-arm64 --no-pub

mkdir -p "$ARTIFACTS"
cp "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$ARTIFACTS/$ARTIFACT_NAME"

SUMS="$ARTIFACTS/SHA256SUMS.txt"
(cd "$ARTIFACTS" && shasum -a 256 "$ARTIFACT_NAME") > "$SUMS"

"$BUILD_TOOLS/apksigner" verify --verbose "$ARTIFACTS/$ARTIFACT_NAME"
"$BUILD_TOOLS/zipalign" -c -P 16 4 "$ARTIFACTS/$ARTIFACT_NAME"
CERT_SHA256="$("$BUILD_TOOLS/apksigner" verify --print-certs "$ARTIFACTS/$ARTIFACT_NAME" | awk '/certificate SHA-256 digest:/ { print tolower($NF); exit }')"
EXPECTED_CERT_SHA256="ed5e9f134d20d2878189f4977515f24c1c5da44a0d744520ae748a69185bc71c"
if [[ "$CERT_SHA256" != "$EXPECTED_CERT_SHA256" ]]; then
  echo "Unexpected signing certificate $CERT_SHA256 (expected $EXPECTED_CERT_SHA256)" >&2
  exit 1
fi

echo "Built $ARTIFACTS/$ARTIFACT_NAME"
shasum -a 256 "$ARTIFACTS/$ARTIFACT_NAME"
