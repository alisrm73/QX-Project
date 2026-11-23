#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f pubspec.yaml ]]; then
  echo "ERROR: pubspec.yaml was not found at the project root." >&2
  exit 1
fi

if [[ -e android ]]; then
  echo "ERROR: android/ already exists. Refusing to overwrite existing Android files." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter is not installed or is not available in PATH." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/qx-android-platform.XXXXXX")"
ANDROID_CREATED=0
cleanup() {
  status=$?
  if [[ $status -ne 0 && "$ANDROID_CREATED" -eq 1 ]]; then
    rm -rf "$ROOT_DIR/android"
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Generating Android platform files with Flutter..."
flutter create \
  --platforms=android \
  --org com.qxstudio \
  --project-name qx_studio \
  "$TMP_DIR/android_shell"

cp -R "$TMP_DIR/android_shell/android" "$ROOT_DIR/android"
ANDROID_CREATED=1

echo "Applying Android secure-storage and backup configuration..."
python3 <<'PY'
from pathlib import Path
import re
import xml.etree.ElementTree as ET

android_dir = Path("android")
manifest_path = android_dir / "app/src/main/AndroidManifest.xml"
if not manifest_path.is_file():
    raise SystemExit(f"ERROR: Generated manifest not found: {manifest_path}")

android_ns = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", android_ns)

tree = ET.parse(manifest_path)
application = tree.getroot().find("application")
if application is None:
    raise SystemExit("ERROR: AndroidManifest.xml has no application element.")

application.set(f"{{{android_ns}}}allowBackup", "true")
application.set(f"{{{android_ns}}}fullBackupContent", "@xml/backup_rules")
application.set(f"{{{android_ns}}}dataExtractionRules", "@xml/data_extraction_rules")
tree.write(manifest_path, encoding="utf-8", xml_declaration=True)

gradle_candidates = [
    android_dir / "app/build.gradle.kts",
    android_dir / "app/build.gradle",
]
gradle_path = next((path for path in gradle_candidates if path.is_file()), None)
if gradle_path is None:
    raise SystemExit("ERROR: Generated app Gradle file was not found.")

gradle_text = gradle_path.read_text(encoding="utf-8")
min_sdk_pattern = re.compile(
    r"^([ \t]*minSdk(?:Version)?[ \t]*(?:=[ \t]*)?)(?:flutter\.minSdkVersion|\d+)([ \t]*(?://.*)?)$",
    re.MULTILINE,
)
gradle_text, replacements = min_sdk_pattern.subn(r"\g<1>23\g<2>", gradle_text)
if replacements != 1:
    raise SystemExit(
        "ERROR: Expected exactly one generated minSdk setting; "
        f"found {replacements}. No safe automatic change was made."
    )
gradle_path.write_text(gradle_text, encoding="utf-8")

xml_dir = android_dir / "app/src/main/res/xml"
xml_dir.mkdir(parents=True, exist_ok=True)

backup_rules = xml_dir / "backup_rules.xml"
if backup_rules.exists():
    raise SystemExit(f"ERROR: Refusing to overwrite existing file: {backup_rules}")
backup_rules.write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <exclude domain="sharedpref" path="FlutterSecureStorage" />
</full-backup-content>
""",
    encoding="utf-8",
)

data_extraction_rules = xml_dir / "data_extraction_rules.xml"
if data_extraction_rules.exists():
    raise SystemExit(
        f"ERROR: Refusing to overwrite existing file: {data_extraction_rules}"
    )
data_extraction_rules.write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="FlutterSecureStorage" />
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="FlutterSecureStorage" />
    </device-transfer>
</data-extraction-rules>
""",
    encoding="utf-8",
)

# Parse every generated XML file touched by this script before reporting success.
ET.parse(manifest_path)
ET.parse(backup_rules)
ET.parse(data_extraction_rules)

if application.get(f"{{{android_ns}}}allowBackup") != "true":
    raise SystemExit("ERROR: Android backup setting verification failed.")
if "@xml/backup_rules" not in application.attrib.values():
    raise SystemExit("ERROR: Legacy backup rules were not linked in the manifest.")
if "@xml/data_extraction_rules" not in application.attrib.values():
    raise SystemExit("ERROR: Android 12+ backup rules were not linked in the manifest.")
if not re.search(r"^[ \t]*minSdk(?:Version)?[ \t]*(?:=[ \t]*)?23\b", gradle_text, re.MULTILINE):
    raise SystemExit("ERROR: Android minSdk verification failed.")

print("Android platform generated and secure-storage backup rules verified.")
print(f"  Manifest: {manifest_path}")
print(f"  Gradle:   {gradle_path} (minSdk 23)")
print(f"  Rules:    {backup_rules}")
print(f"            {data_extraction_rules}")
PY

echo "Preparation complete. No APK was built by this script."
