# Builds libpiper for iOS
cmake_minimum_required(VERSION 3.26)
project(piper_ios LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# iOS specific settings
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum iOS deployment version")
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Target architectures")

include(ExternalProject)

# Install location for espeak-ng
set(ESPEAKNG_BUILD_DIR ${CMAKE_BINARY_DIR}/espeak_ng)
set(ESPEAKNG_INSTALL_DIR ${CMAKE_BINARY_DIR}/espeak_ng-install)
set(ESPEAKNG_STATIC_LIB ${ESPEAKNG_INSTALL_DIR}/lib/libespeak-ng.a)
set(UCD_STATIC_LIB ${ESPEAKNG_BUILD_DIR}/src/espeak_ng_external-build/src/ucd-tools/libucd.a)

ExternalProject_Add(espeak_ng_external
    GIT_REPOSITORY https://github.com/espeak-ng/espeak-ng.git
    GIT_TAG 212928b394a96e8fd2096616bfd54e17845c48f6  # 2025-Mar-22
    PREFIX ${ESPEAKNG_BUILD_DIR}
    CMAKE_ARGS
        -DCMAKE_SYSTEM_NAME=iOS
        -DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}
        -DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}
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

include_directories(
    ${ESPEAKNG_INSTALL_DIR}/include
)

# ---- onnxruntime ---

if(NOT DEFINED ONNXRUNTIME_DIR)
    set(ONNXRUNTIME_VERSION "1.22.0")
    set(ONNXRUNTIME_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/onnxruntime-ios-${ONNXRUNTIME_VERSION}")
    
    # For iOS, ONNX Runtime is distributed as an XCFramework
    # The build script should download and extract it
    if(NOT EXISTS "${ONNXRUNTIME_DIR}")
        message(WARNING "ONNX Runtime iOS not found at ${ONNXRUNTIME_DIR}")
        message(WARNING "Please run build_xcframework.sh to download it")
    endif()
endif()

# Path to the libpiper source
set(LIBPIPER_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../libpiper)

# ---- libpiper ---

add_library(piper STATIC
    ${LIBPIPER_ROOT}/src/piper.cpp
)

add_dependencies(piper espeak_ng_external)

target_include_directories(piper PUBLIC
    ${ESPEAKNG_INSTALL_DIR}/include
    ${ONNXRUNTIME_DIR}/include
    ${LIBPIPER_ROOT}/include
)

target_link_directories(piper PUBLIC
    ${ONNXRUNTIME_DIR}/lib
)

target_link_libraries(piper
    ${ESPEAKNG_STATIC_LIB}
    ${UCD_STATIC_LIB}
    "-framework Foundation"
    "-framework CoreML"
)

# Note: ONNX Runtime for iOS is provided as an XCFramework
# It should be linked separately in the Xcode project

# ---- install ---

include(GNUInstallDirs)

install(TARGETS piper
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

install(
    FILES ${LIBPIPER_ROOT}/include/piper.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(
    FILES ${LIBPIPER_ROOT}/include/uchar_compat.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Copy espeak-ng-data
if(EXISTS ${ESPEAKNG_INSTALL_DIR}/share/espeak-ng-data)
    install(
        DIRECTORY ${ESPEAKNG_INSTALL_DIR}/share/espeak-ng-data
        DESTINATION ${CMAKE_INSTALL_PREFIX}/share
    )
endif()
