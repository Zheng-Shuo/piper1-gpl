#ifndef UCHAR_COMPAT_H_
#define UCHAR_COMPAT_H_

// Compatibility header for <uchar.h>
// Some platforms (older Android NDK, iOS SDK) may not have <uchar.h>
// This header provides fallback definitions for char32_t

#if defined(__ANDROID__) && __ANDROID_API__ < 21
    // Android API < 21 doesn't have uchar.h
    #include <stdint.h>
    typedef uint32_t char32_t;
    typedef uint16_t char16_t;
#elif defined(__APPLE__)
    // iOS and macOS may not have uchar.h in older SDKs
    #if !__has_include(<uchar.h>)
        #include <stdint.h>
        typedef uint32_t char32_t;
        typedef uint16_t char16_t;
    #else
        #include <uchar.h>
    #endif
#else
    // Most modern platforms have uchar.h
    #if __has_include(<uchar.h>)
        #include <uchar.h>
    #else
        // Fallback for platforms without uchar.h
        #include <stdint.h>
        typedef uint32_t char32_t;
        typedef uint16_t char16_t;
    #endif
#endif

#endif // UCHAR_COMPAT_H_
