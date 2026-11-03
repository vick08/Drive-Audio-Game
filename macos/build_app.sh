#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MACOS_DIR="${ROOT_DIR}/macos"
SRC_DIR="${MACOS_DIR}/Sources"
RES_DIR="${MACOS_DIR}/Resources"
APP_BUNDLE="${ROOT_DIR}/Drive.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_BIN_DIR="${CONTENTS_DIR}/MacOS"
BUNDLE_RES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "${MACOS_BIN_DIR}" "${BUNDLE_RES_DIR}"

cat > "${CONTENTS_DIR}/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>nl</string>
    <key>CFBundleExecutable</key>
    <string>Drive</string>
    <key>CFBundleIdentifier</key>
    <string>nl.hku.audiogames.drive</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Drive</string>
    <key>CFBundleDisplayName</key>
    <string>Drive</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>2002.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

cp -f "${RES_DIR}/cps_patches.json" "${BUNDLE_RES_DIR}/cps_patches.json"
ln -sfn "../../Xtras" "${BUNDLE_RES_DIR}/Xtras"
ln -sfn "../../pics" "${BUNDLE_RES_DIR}/pics"

echo "Compiling Drive.app..."
swiftc -O \
    -framework AppKit \
    -framework AVFoundation \
    -framework Foundation \
    "${SRC_DIR}/CPSAudioEngine.swift" \
    "${SRC_DIR}/DirectorRuntime.swift" \
    "${SRC_DIR}/AppShell.swift" \
    "${SRC_DIR}/VerifySuite.swift" \
    "${SRC_DIR}/main.swift" \
    -o "${MACOS_BIN_DIR}/Drive"

chmod +x "${MACOS_BIN_DIR}/Drive"
echo "Built ${APP_BUNDLE} successfully."
