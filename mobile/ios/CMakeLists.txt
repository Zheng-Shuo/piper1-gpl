cmake_minimum_required(VERSION 3.26)
project(piper_ios LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# iOS-specific settings
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum iOS deployment version")
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Build architectures for iOS")

include(ExternalProject)

# Get the libpiper source directory
set(LIBPIPER_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../libpiper)

# Install location for espeak-ng
set(ESPEAKNG_BUILD_DIR ${CMAKE_BINARY_DIR}/espeak_ng)
set(ESPEAKNG_INSTALL_DIR ${CMAKE_BINARY_DIR}/espeak_ng-install)
set(ESPEAKNG_STATIC_LIB ${ESPEAKNG_INSTALL_DIR}/lib/libespeak-ng.a)
set(UCD_STATIC_LIB ${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external-build/src/ucd-tools/libucd.a)

# Cross-compile espeak-ng for iOS
ExternalProject_Add(espeak_ng_external
    GIT_REPOSITORY https://github.com/espeak-ng/espeak-ng.git
    GIT_TAG 212928b394a96e8fd2096616bfd54e17845c48f6
    PREFIX ${ESPEAKNG_BUILD_DIR}
    CMAKE_ARGS
        -DCMAKE_SYSTEM_NAME=iOS
        -DCMAKE_OSX_ARCHITECTURES=arm64
        -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0
        -DCMAKE_INSTALL_PREFIX=${ESPEAKNG_INSTALL_DIR}
        -DBUILD_SHARED_LIBS:BOOL=OFF
        -DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON
        -DUSE_ASYNC:BOOL=OFF
        -DUSE_MBROLA:BOOL=OFF
        -DUSE_LIBSONIC:BOOL=OFF
        -DUSE_LIBPCAUDIO:BOOL=OFF
        -DUSE_KLATT:BOOL=OFF
        -DUSE_SPEECHPLAYER:BOOL=OFF
        -DEXTRA_cmn:BOOL=ON
        -DEXTRA_ru:BOOL=ON
        "-DCMAKE_C_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
        "-DCMAKE_CXX_FLAGS=-D_FILE_OFFSET_BITS=64 -I${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external/src/ucd-tools/src/include"
    BUILD_BYPRODUCTS
        ${ESPEAKNG_STATIC_LIB}
        ${UCD_STATIC_LIB}
    UPDATE_DISCONNECTED TRUE
)

# ---- ONNX Runtime ----

set(ONNXRUNTIME_VERSION "1.22.0")
set(ONNXRUNTIME_IOS_URL "https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/onnxruntime-ios-${ONNXRUNTIME_VERSION}.zip")
set(ONNXRUNTIME_ZIP_FILE "${CMAKE_BINARY_DIR}/onnxruntime-ios.zip")
set(ONNXRUNTIME_EXTRACTED_DIR "${CMAKE_BINARY_DIR}/onnxruntime-ios")

# Download ONNX Runtime for iOS if not already present
if(NOT EXISTS "${ONNXRUNTIME_ZIP_FILE}")
    message(STATUS "Downloading ONNX Runtime iOS...")
    file(DOWNLOAD "${ONNXRUNTIME_IOS_URL}" "${ONNXRUNTIME_ZIP_FILE}"
         SHOW_PROGRESS
         STATUS DOWNLOAD_STATUS)
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    if(NOT STATUS_CODE EQUAL 0)
        message(FATAL_ERROR "Failed to download ONNX Runtime iOS")
    endif()
endif()

# Extract iOS framework
if(NOT EXISTS "${ONNXRUNTIME_EXTRACTED_DIR}")
    message(STATUS "Extracting ONNX Runtime iOS...")
    file(ARCHIVE_EXTRACT
         INPUT "${ONNXRUNTIME_ZIP_FILE}"
         DESTINATION "${ONNXRUNTIME_EXTRACTED_DIR}")
endif()

# Find the onnxruntime framework
set(ONNXRUNTIME_FRAMEWORK "${ONNXRUNTIME_EXTRACTED_DIR}/onnxruntime.xcframework/ios-arm64/onnxruntime.framework")
set(ONNXRUNTIME_INCLUDE_DIR "${ONNXRUNTIME_FRAMEWORK}/Headers")
set(ONNXRUNTIME_LIB "${ONNXRUNTIME_FRAMEWORK}/onnxruntime")

# ---- libpiper ----

add_library(piper STATIC
    ${LIBPIPER_SOURCE_DIR}/src/piper.cpp
)

add_dependencies(piper espeak_ng_external)

target_include_directories(piper PUBLIC
    ${ESPEAKNG_INSTALL_DIR}/include
    ${ONNXRUNTIME_INCLUDE_DIR}
    ${LIBPIPER_SOURCE_DIR}/include
)

target_link_libraries(piper
    ${ESPEAKNG_STATIC_LIB}
    ${UCD_STATIC_LIB}
    ${ONNXRUNTIME_LIB}
)

# ---- Install ----

install(TARGETS piper
    ARCHIVE DESTINATION ${CMAKE_INSTALL_PREFIX}/lib
)

install(
    FILES ${LIBPIPER_SOURCE_DIR}/include/piper.h
    DESTINATION ${CMAKE_INSTALL_PREFIX}/include
)

install(
    DIRECTORY ${ESPEAKNG_INSTALL_DIR}/share/espeak-ng-data
    DESTINATION ${CMAKE_INSTALL_PREFIX}
)
