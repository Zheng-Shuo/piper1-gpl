#!/bin/bash
set -e

echo "========================================="
echo "Building Piper XCFramework for iOS"
echo "========================================="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
XCFRAMEWORK_DIR="${SCRIPT_DIR}/xcframework"
LIBPIPER_ROOT="${SCRIPT_DIR}/../../libpiper"

# Clean previous builds
rm -rf "${BUILD_DIR}"
rm -rf "${XCFRAMEWORK_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${XCFRAMEWORK_DIR}"

# iOS build settings
IOS_DEPLOYMENT_TARGET="15.0"
IOS_ARCH="arm64"
ONNXRUNTIME_VERSION="1.22.0"

echo ""
echo "Step 1: Building espeak-ng for iOS..."
echo "========================================="

ESPEAKNG_BUILD_DIR="${BUILD_DIR}/espeak-ng-build"
ESPEAKNG_INSTALL_DIR="${BUILD_DIR}/espeak-ng-install"

mkdir -p "${ESPEAKNG_BUILD_DIR}"

cd "${ESPEAKNG_BUILD_DIR}"
cmake "${SCRIPT_DIR}/../../" \
    -G "Unix Makefiles" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="${IOS_ARCH}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET}" \
    -DCMAKE_INSTALL_PREFIX="${ESPEAKNG_INSTALL_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DUSE_ASYNC=OFF \
    -DUSE_MBROLA=OFF \
    -DUSE_LIBSONIC=OFF \
    -DUSE_LIBPCAUDIO=OFF \
    -DUSE_KLATT=OFF \
    -DUSE_SPEECHPLAYER=OFF \
    -DEXTRA_cmn=ON \
    -DEXTRA_ru=ON

# Note: The above uses a CMakeLists.txt that should build espeak-ng
# For now, we'll use ExternalProject in the iOS CMakeLists.txt instead

echo ""
echo "Step 2: Downloading ONNX Runtime for iOS..."
echo "========================================="

ONNXRUNTIME_ZIP="onnxruntime-ios-${ONNXRUNTIME_VERSION}.zip"
ONNXRUNTIME_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/onnxruntime-ios-${ONNXRUNTIME_VERSION}.zip"
ONNXRUNTIME_DIR="${BUILD_DIR}/onnxruntime-ios"

if [ ! -f "${BUILD_DIR}/${ONNXRUNTIME_ZIP}" ]; then
    echo "Downloading ${ONNXRUNTIME_URL}..."
    curl -L -o "${BUILD_DIR}/${ONNXRUNTIME_ZIP}" "${ONNXRUNTIME_URL}"
fi

if [ ! -d "${ONNXRUNTIME_DIR}" ]; then
    echo "Extracting ONNX Runtime..."
    unzip -q "${BUILD_DIR}/${ONNXRUNTIME_ZIP}" -d "${BUILD_DIR}"
    # The extracted directory might be named differently
    mv "${BUILD_DIR}/onnxruntime-ios-xcframework-"* "${ONNXRUNTIME_DIR}" 2>/dev/null || true
fi

echo ""
echo "Step 3: Building libpiper for iOS..."
echo "========================================="

LIBPIPER_BUILD_DIR="${BUILD_DIR}/libpiper-build"
LIBPIPER_INSTALL_DIR="${BUILD_DIR}/libpiper-install"

mkdir -p "${LIBPIPER_BUILD_DIR}"
cd "${LIBPIPER_BUILD_DIR}"

cmake "${SCRIPT_DIR}" \
    -G "Unix Makefiles" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="${IOS_ARCH}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET}" \
    -DCMAKE_INSTALL_PREFIX="${LIBPIPER_INSTALL_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DONNXRUNTIME_DIR="${ONNXRUNTIME_DIR}"

make -j$(sysctl -n hw.ncpu)
make install

echo ""
echo "Step 4: Creating XCFramework..."
echo "========================================="

# Create the XCFramework structure
XCFRAMEWORK_NAME="PiperTTS.xcframework"
XCFRAMEWORK_PATH="${XCFRAMEWORK_DIR}/${XCFRAMEWORK_NAME}"

mkdir -p "${XCFRAMEWORK_PATH}/ios-arm64"
mkdir -p "${XCFRAMEWORK_PATH}/ios-arm64/Headers"

# Copy the static library
cp "${LIBPIPER_INSTALL_DIR}/lib/libpiper.a" "${XCFRAMEWORK_PATH}/ios-arm64/"

# Copy headers
cp "${LIBPIPER_ROOT}/include/piper.h" "${XCFRAMEWORK_PATH}/ios-arm64/Headers/"
cp "${LIBPIPER_ROOT}/include/uchar_compat.h" "${XCFRAMEWORK_PATH}/ios-arm64/Headers/"

# Create Info.plist for XCFramework
cat > "${XCFRAMEWORK_PATH}/Info.plist" << EOF
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
            <string>libpiper.a</string>
            <key>HeadersPath</key>
            <string>Headers</string>
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

echo ""
echo "Step 5: Packaging espeak-ng-data..."
echo "========================================="

# Copy espeak-ng-data to a resource bundle
ESPEAK_DATA_SRC="${ESPEAKNG_INSTALL_DIR}/share/espeak-ng-data"
ESPEAK_DATA_BUNDLE="${XCFRAMEWORK_DIR}/espeak-ng-data"

if [ -d "${ESPEAK_DATA_SRC}" ]; then
    cp -r "${ESPEAK_DATA_SRC}" "${ESPEAK_DATA_BUNDLE}"
    echo "espeak-ng-data copied to ${ESPEAK_DATA_BUNDLE}"
else
    echo "Warning: espeak-ng-data not found at ${ESPEAK_DATA_SRC}"
fi

echo ""
echo "Step 6: Creating distribution archive..."
echo "========================================="

cd "${XCFRAMEWORK_DIR}"
zip -r "PiperTTS-ios-${IOS_ARCH}.zip" "${XCFRAMEWORK_NAME}" espeak-ng-data

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo "XCFramework: ${XCFRAMEWORK_PATH}"
echo "Archive: ${XCFRAMEWORK_DIR}/PiperTTS-ios-${IOS_ARCH}.zip"
echo ""
