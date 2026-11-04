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

rm -rf "${BUNDLE_RES_DIR}/Xtras" "${BUNDLE_RES_DIR}/pics"
echo "Copying runtime assets into app bundle..."
cp -R "${ROOT_DIR}/Xtras" "${BUNDLE_RES_DIR}/Xtras"
cp -R "${ROOT_DIR}/pics" "${BUNDLE_RES_DIR}/pics"
cp -f "${RES_DIR}/cps_patches.json" "${BUNDLE_RES_DIR}/cps_patches.json"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${BUILD_DIR}"' EXIT

SWIFT_SOURCES=(
    "${SRC_DIR}/CPSAudioEngine.swift"
    "${SRC_DIR}/DirectorRuntime.swift"
    "${SRC_DIR}/AppShell.swift"
    "${SRC_DIR}/VerifySuite.swift"
    "${SRC_DIR}/main.swift"
)

echo "Compiling Drive for Apple Silicon (arm64)..."
swiftc -O -target arm64-apple-macos12.0 \
    -framework AppKit \
    -framework AVFoundation \
    -framework Foundation \
    "${SWIFT_SOURCES[@]}" \
    -o "${BUILD_DIR}/Drive_arm64"

echo "Compiling Drive for Intel (x86_64)..."
swiftc -O -target x86_64-apple-macos12.0 \
    -framework AppKit \
    -framework AVFoundation \
    -framework Foundation \
    "${SWIFT_SOURCES[@]}" \
    -o "${BUILD_DIR}/Drive_x86_64"

echo "Creating Universal binary (arm64 + x86_64)..."
lipo -create -output "${MACOS_BIN_DIR}/Drive" "${BUILD_DIR}/Drive_arm64" "${BUILD_DIR}/Drive_x86_64"
chmod +x "${MACOS_BIN_DIR}/Drive"

echo "Ad-hoc signing Drive.app..."
codesign --force --deep --sign - "${APP_BUNDLE}" > /dev/null 2>&1 || true

echo "Built ${APP_BUNDLE} successfully."
