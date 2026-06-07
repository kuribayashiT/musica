#!/bin/bash
set -euo pipefail

# =============================================================================
# musica — TestFlight upload script
# Usage: ./upload_testflight.sh
# =============================================================================

WORKSPACE="musica.xcworkspace"
SCHEME="musica"
TEAM_ID="SCU9EZ2EKX"
BUNDLE_ID="kuriFCTmusica"
ARCHIVE_PATH="build/musica.xcarchive"
EXPORT_PATH="build/musica_export"
EXPORT_OPTIONS="build/exportOptions.plist"

# ── Apple ID & App-Specific Password ─────────────────────────────────────────
if [[ -z "${APPLE_ID:-}" ]]; then
  read -rp "Apple ID (例: foo@example.com): " APPLE_ID
fi

if [[ -z "${APP_SPECIFIC_PASSWORD:-}" ]]; then
  read -rsp "App-Specific Password (appleid.apple.com で発行): " APP_SPECIFIC_PASSWORD
  echo ""
fi

# ── Export Options plist を生成 ───────────────────────────────────────────────
mkdir -p build
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

echo ""
echo "========================================"
echo " STEP 1: Archive (Generic iOS Device)"
echo "========================================"
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive

echo ""
echo "========================================"
echo " STEP 2: Export IPA (App Store)"
echo "========================================"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

IPA_PATH=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
if [[ -z "$IPA_PATH" ]]; then
  echo "Error: IPA not found in $EXPORT_PATH"
  exit 1
fi
echo "IPA: $IPA_PATH"

echo ""
echo "========================================"
echo " STEP 3: Upload to App Store Connect"
echo "========================================"
xcrun altool \
  --upload-app \
  --type ios \
  --file "$IPA_PATH" \
  --username "$APPLE_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --verbose

echo ""
echo "========================================"
echo " Done! TestFlight へのデリバリー完了"
echo " App Store Connect で処理完了を確認してください"
echo "========================================"
