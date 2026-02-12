cmake_minimum_required(VERSION 3.22.1)
project(piper_jni C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Path to the libpiper source
set(LIBPIPER_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../libpiper)

include(ExternalProject)

# ========================================
# espeak-ng - cross-compile for Android
# ========================================

set(ESPEAKNG_BUILD_DIR ${CMAKE_BINARY_DIR}/espeak_ng)
set(ESPEAKNG_INSTALL_DIR ${CMAKE_BINARY_DIR}/espeak_ng-install)
set(ESPEAKNG_STATIC_LIB ${ESPEAKNG_INSTALL_DIR}/lib/libespeak-ng.a)
set(UCD_STATIC_LIB ${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external-build/src/ucd-tools/libucd.a)

ExternalProject_Add(espeak_ng_external
    GIT_REPOSITORY https://github.com/espeak-ng/espeak-ng.git
    GIT_TAG 212928b394a96e8fd2096616bfd54e17845c48f6  # 2025-Mar-22
    PREFIX ${ESPEAKNG_BUILD_DIR}
    CMAKE_ARGS
        -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake
        -DANDROID_ABI=${ANDROID_ABI}
        -DANDROID_PLATFORM=android-${ANDROID_PLATFORM_LEVEL}
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

# ========================================
# ONNX Runtime - download Android AAR
# ========================================

set(ONNXRUNTIME_VERSION "1.22.0")
set(ONNXRUNTIME_AAR_URL "https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/${ONNXRUNTIME_VERSION}/onnxruntime-android-${ONNXRUNTIME_VERSION}.aar")
set(ONNXRUNTIME_AAR_FILE "${CMAKE_BINARY_DIR}/onnxruntime-android-${ONNXRUNTIME_VERSION}.aar")
set(ONNXRUNTIME_EXTRACT_DIR "${CMAKE_BINARY_DIR}/onnxruntime-extracted")
set(ONNXRUNTIME_SO "${ONNXRUNTIME_EXTRACT_DIR}/jni/${ANDROID_ABI}/libonnxruntime.so")
set(ONNXRUNTIME_INCLUDE_DIR "${ONNXRUNTIME_EXTRACT_DIR}/headers")

# Download AAR if not exists
if(NOT EXISTS "${ONNXRUNTIME_AAR_FILE}")
    message(STATUS "Downloading ONNX Runtime AAR...")
    file(DOWNLOAD "${ONNXRUNTIME_AAR_URL}" "${ONNXRUNTIME_AAR_FILE}"
         SHOW_PROGRESS
         STATUS DOWNLOAD_STATUS)
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    if(NOT STATUS_CODE EQUAL 0)
        message(FATAL_ERROR "Failed to download ONNX Runtime AAR")
    endif()
endif()

# Extract AAR (it's a ZIP file)
if(NOT EXISTS "${ONNXRUNTIME_EXTRACT_DIR}")
    message(STATUS "Extracting ONNX Runtime AAR...")
    file(ARCHIVE_EXTRACT INPUT "${ONNXRUNTIME_AAR_FILE}" DESTINATION "${ONNXRUNTIME_EXTRACT_DIR}")
endif()

# Verify the .so file exists
if(NOT EXISTS "${ONNXRUNTIME_SO}")
    message(FATAL_ERROR "ONNX Runtime .so not found at ${ONNXRUNTIME_SO}")
endif()

# Import ONNX Runtime as a shared library
add_library(onnxruntime SHARED IMPORTED)
set_target_properties(onnxruntime PROPERTIES
    IMPORTED_LOCATION "${ONNXRUNTIME_SO}"
)

# ========================================
# libpiper - compile for Android
# ========================================

add_library(piper SHARED
    ${LIBPIPER_ROOT}/src/piper.cpp
)

add_dependencies(piper espeak_ng_external)

target_include_directories(piper PUBLIC
    ${ESPEAKNG_INSTALL_DIR}/include
    ${ONNXRUNTIME_INCLUDE_DIR}
    ${LIBPIPER_ROOT}/include
)

target_link_libraries(piper
    ${ESPEAKNG_STATIC_LIB}
    ${UCD_STATIC_LIB}
    onnxruntime
    log
)

# ========================================
# piper_jni - JNI bridge
# ========================================

add_library(piper_jni SHARED
    piper_jni.cpp
)

target_include_directories(piper_jni PRIVATE
    ${LIBPIPER_ROOT}/include
)

target_link_libraries(piper_jni
    piper
    log
)

# ========================================
# Package espeak-ng-data as assets
# ========================================

# Note: espeak-ng-data directory will be copied to assets in a post-build step
# or packaged separately and extracted at runtime by the Android app
