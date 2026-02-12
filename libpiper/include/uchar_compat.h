#ifndef UCHAR_COMPAT_H_
#define UCHAR_COMPAT_H_

// Compatibility header for platforms that don't have <uchar.h>
// This is needed for Android NDK < API 28 and some iOS SDK versions

#if defined(__ANDROID__) || defined(__APPLE__)
  // For Android and iOS, uchar.h might not be available
  // char32_t is typically defined in <cstdint> or <stdint.h>
  #include <stdint.h>
  
  #ifndef __cplusplus
    // In C, we need to define char32_t if not already defined
    #ifndef _CHAR32_T
      #define _CHAR32_T
      typedef uint32_t char32_t;
    #endif
  #endif
#else
  // On other platforms, use the standard header
  #include <uchar.h>
#endif

#endif // UCHAR_COMPAT_H_
