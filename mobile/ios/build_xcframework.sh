#!/bin/bash
set -e

# Build script for creating PiperTTS XCFramework for iOS
# This script:
# 1. Cross-compiles espeak-ng for iOS arm64
# 2. Downloads ONNX Runtime iOS
# 3. Builds libpiper as a static library
# 4. Creates an XCFramework with all dependencies

echo "=== Building PiperTTS XCFramework for iOS ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
INSTALL_DIR="${SCRIPT_DIR}/install"

# Clean previous build
if [ -d "${BUILD_DIR}" ]; then
    echo "Cleaning previous build..."
    rm -rf "${BUILD_DIR}"
fi

if [ -d "${INSTALL_DIR}" ]; then
    echo "Cleaning previous install..."
    rm -rf "${INSTALL_DIR}"
fi

mkdir -p "${BUILD_DIR}"
mkdir -p "${INSTALL_DIR}"

# Step 1: Configure and build with CMake
echo "Configuring build for iOS arm64..."
cmake -S "${SCRIPT_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"

echo "Building..."
cmake --build "${BUILD_DIR}" -j$(sysctl -n hw.ncpu)

echo "Installing..."
cmake --install "${BUILD_DIR}"

# Step 2: Create XCFramework structure
XCFRAMEWORK_DIR="${BUILD_DIR}/PiperTTS.xcframework"
FRAMEWORK_DIR="${XCFRAMEWORK_DIR}/ios-arm64/PiperTTS.framework"

echo "Creating XCFramework structure..."
mkdir -p "${FRAMEWORK_DIR}/Headers"
mkdir -p "${FRAMEWORK_DIR}/Modules"

# Copy library
echo "Copying libpiper.a..."
cp "${INSTALL_DIR}/lib/libpiper.a" "${FRAMEWORK_DIR}/PiperTTS"

# Copy headers
echo "Copying headers..."
cp "${INSTALL_DIR}/include/piper.h" "${FRAMEWORK_DIR}/Headers/"

# Create module map
echo "Creating module map..."
cat > "${FRAMEWORK_DIR}/Modules/module.modulemap" << 'EOF'
framework module PiperTTS {
    umbrella header "PiperTTS.h"
    export *
    module * { export * }
}
EOF

# Create umbrella header
cat > "${FRAMEWORK_DIR}/Headers/PiperTTS.h" << 'EOF'
//
//  PiperTTS.h
//  PiperTTS
//
//  Umbrella header for PiperTTS framework
//

#import <Foundation/Foundation.h>

//! Project version number for PiperTTS.
FOUNDATION_EXPORT double PiperTTSVersionNumber;

//! Project version string for PiperTTS.
FOUNDATION_EXPORT const unsigned char PiperTTSVersionString[];

// Import the C API
#include "piper.h"
EOF

# Create Info.plist for the framework
cat > "${FRAMEWORK_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PiperTTS</string>
    <key>CFBundleIdentifier</key>
    <string>com.piper.tts</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PiperTTS</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>15.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
</dict>
</plist>
EOF

# Create XCFramework Info.plist
cat > "${XCFRAMEWORK_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>LibraryIdentifier</key>
            <string>ios-arm64</string>
            <key>LibraryPath</key>
            <string>PiperTTS.framework</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>ios</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

# Step 3: Create resource bundle for espeak-ng-data
BUNDLE_DIR="${BUILD_DIR}/EspeakNGData.bundle"
echo "Creating espeak-ng-data resource bundle..."
mkdir -p "${BUNDLE_DIR}"
cp -r "${INSTALL_DIR}/espeak-ng-data" "${BUNDLE_DIR}/"

cat > "${BUNDLE_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleIdentifier</key>
    <string>com.piper.tts.espeak</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>EspeakNGData</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF

# Step 4: Create a zip archive for distribution
echo "Creating distribution archive..."
cd "${BUILD_DIR}"
zip -r PiperTTS-iOS.zip PiperTTS.xcframework EspeakNGData.bundle

echo ""
echo "=== Build complete! ==="
echo ""
echo "XCFramework: ${XCFRAMEWORK_DIR}"
echo "Resource bundle: ${BUNDLE_DIR}"
echo "Distribution zip: ${BUILD_DIR}/PiperTTS-iOS.zip"
echo ""
echo "To use in your Xcode project:"
echo "1. Drag PiperTTS.xcframework to your project"
echo "2. Add EspeakNGData.bundle to your app target"
echo "3. Add onnxruntime-c framework (via CocoaPods or manually)"
echo ""
