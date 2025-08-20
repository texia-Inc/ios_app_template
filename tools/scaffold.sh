#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <APP_NAME> <BUNDLE_ID> [CONFIG_FILE]"
    echo "Example: $0 'Coin Blaster' 'com.texia.coinblaster' app.yaml"
    exit 1
fi

APP_NAME="$1"
BUNDLE_ID="$2"
CFG="${3:-app.yaml}"

TARGET="apps/${APP_NAME// /_}"

echo "Creating app: $APP_NAME"
echo "Bundle ID: $BUNDLE_ID"
echo "Target directory: $TARGET"

# Check if source app exists
if [ ! -d "apps/sample_app" ]; then
    echo "Error: apps/sample_app not found. Please create it first."
    exit 1
fi

# Copy sample_app to new target
echo "Copying sample_app to $TARGET..."
rsync -a apps/sample_app/ "${TARGET}/"

# Replace bundle ID and app name in files
echo "Updating bundle ID and app name..."
find "${TARGET}" \( -name "*.dart" -o -name "Info.plist" -o -name "project.pbxproj" -o -name "pubspec.yaml" \) -print0 \
  | xargs -0 sed -i.bak -e "s/com.texia.sample/${BUNDLE_ID}/g" -e "s/Sample App/${APP_NAME}/g" -e "s/sample_app/${APP_NAME// /_}/g"

# Update iOS Info.plist with proper tools
if [ -f "${TARGET}/ios/Runner/Info.plist" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${TARGET}/ios/Runner/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "${TARGET}/ios/Runner/Info.plist" 2>/dev/null || true
fi

# Generate assets if tools are available
if [ -f "tools/gen_assets.dart" ]; then
    echo "Generating assets..."
    dart run tools/gen_assets.dart "${CFG}" "${TARGET}"
fi

# Generate metadata if tools are available
if [ -f "tools/gen_metadata.ts" ]; then
    echo "Generating metadata..."
    node tools/gen_metadata.ts "${CFG}" "fastlane/metadata"
fi

# Clean up backup files
find "${TARGET}" -name "*.bak" -delete

echo "✅ Created ${TARGET}"
echo "Next steps:"
echo "  cd ${TARGET} && flutter pub get"
echo "  flutter run"