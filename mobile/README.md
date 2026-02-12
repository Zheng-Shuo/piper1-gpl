# Mobile Platform Build Support

This directory contains the infrastructure for building Piper TTS for mobile platforms (Android and iOS).

## Overview

Piper TTS can be compiled as a native library for Android (AAR) and iOS (XCFramework), allowing offline text-to-speech synthesis on mobile devices.

### Supported Platforms

- **Android**: arm64-v8a (API 24+)
- **iOS**: arm64 (iOS 15.0+)

### Dependencies

- **espeak-ng**: Text-to-phoneme conversion (built from source)
- **ONNX Runtime 1.22.0**: Neural network inference
- **nlohmann/json**: JSON parsing (header-only, included)
- **uni_algo**: Unicode algorithms (header-only, included)

## Building for Android

### Prerequisites

- JDK 17 or later
- Android SDK with NDK r26 (26.1.10909125)
- CMake 3.22.1 or later

### Build Steps

1. Navigate to the Android directory:
   ```bash
   cd mobile/android
   ```

2. Run the Gradle build:
   ```bash
   ./gradlew :piper:assembleRelease
   ```

3. The AAR file will be generated at:
   ```
   mobile/android/piper/build/outputs/aar/piper-release.aar
   ```

### Integration in Android Apps

#### 1. Add the AAR to your project

Copy the AAR file to your app's `libs` directory and add to `build.gradle`:

```gradle
dependencies {
    implementation files('libs/piper-release.aar')
    implementation 'androidx.annotation:annotation:1.7.0'
}
```

#### 2. Bundle required runtime files

You need to include three types of files in your app:

- **Voice model**: `*.onnx` file
- **Voice config**: `*.onnx.json` file
- **espeak-ng-data**: Directory with phoneme data

Place these files in your app's assets and copy them to internal storage at runtime:

```java
// Example: Copy espeak-ng-data from assets to internal storage
private void copyAssetsToInternalStorage() {
    String targetDir = getFilesDir() + "/espeak-ng-data";
    // Copy all files from assets/espeak-ng-data to targetDir
    // ... (implementation depends on your asset structure)
}
```

#### 3. Use the API

```java
import com.piper.tts.PiperTTS;

// Initialize
String modelPath = getFilesDir() + "/models/en_US-lessac-medium.onnx";
String configPath = null; // Will use modelPath + ".json"
String espeakDataPath = getFilesDir() + "/espeak-ng-data";

PiperTTS tts = new PiperTTS(modelPath, configPath, espeakDataPath);

// Synthesize
String text = "Hello, this is a test.";
short[] pcmData = tts.synthesize(text);
int sampleRate = tts.getSampleRate();

// Play the audio using AudioTrack or save to file
// ...

// Clean up
tts.release();
```

#### 4. Play audio with AudioTrack

```java
import android.media.AudioTrack;
import android.media.AudioFormat;
import android.media.AudioManager;

AudioTrack audioTrack = new AudioTrack(
    AudioManager.STREAM_MUSIC,
    sampleRate,
    AudioFormat.CHANNEL_OUT_MONO,
    AudioFormat.ENCODING_PCM_16BIT,
    pcmData.length * 2,
    AudioTrack.MODE_STATIC
);

audioTrack.write(pcmData, 0, pcmData.length);
audioTrack.play();
```

## Building for iOS

### Prerequisites

- macOS with Xcode 15.2 or later
- CMake 3.26 or later
- Command Line Tools for Xcode

### Build Steps

1. Navigate to the iOS directory:
   ```bash
   cd mobile/ios
   ```

2. Run the build script:
   ```bash
   ./build_xcframework.sh
   ```

3. The XCFramework and espeak-ng-data will be packaged at:
   ```
   mobile/ios/xcframework/PiperTTS-ios-arm64.zip
   ```

### Integration in iOS Apps

#### 1. Add the XCFramework to your project

1. Extract `PiperTTS-ios-arm64.zip`
2. Drag `PiperTTS.xcframework` into your Xcode project
3. In your target's settings, under "Frameworks, Libraries, and Embedded Content", set it to "Embed & Sign"
4. Add ONNX Runtime dependency (via CocoaPods or manual):
   ```ruby
   # Podfile
   pod 'onnxruntime-objc', '~> 1.22.0'
   ```

#### 2. Bundle required runtime files

Add to your app bundle:
- **Voice model**: `*.onnx` file
- **Voice config**: `*.onnx.json` file  
- **espeak-ng-data**: Directory (add to project as folder reference)

#### 3. Use the API

```swift
import PiperTTS

do {
    // Initialize
    let modelPath = Bundle.main.path(forResource: "en_US-lessac-medium", ofType: "onnx")!
    let espeakDataPath = Bundle.main.path(forResource: "espeak-ng-data", ofType: nil)!
    
    let tts = try PiperTTS(modelPath: modelPath, espeakDataPath: espeakDataPath)
    
    // Synthesize to PCM data
    let text = "Hello, this is a test."
    let audioData = try tts.synthesize(text: text)
    let sampleRate = tts.sampleRateHz
    
    // Or get float samples
    let floatSamples = try tts.synthesizeToFloat(text: text)
    
    // Play the audio using AVAudioPlayer or AVAudioEngine
    // ...
    
} catch {
    print("Error: \\(error)")
}
```

#### 4. Play audio with AVAudioPlayer

```swift
import AVFoundation

func playAudio(pcmData: Data, sampleRate: Int) {
    // Convert PCM to WAV format
    let wavData = createWAVData(pcmData: pcmData, sampleRate: sampleRate)
    
    do {
        let player = try AVAudioPlayer(data: wavData)
        player.play()
    } catch {
        print("Failed to play audio: \\(error)")
    }
}

func createWAVData(pcmData: Data, sampleRate: Int) -> Data {
    var wavData = Data()
    
    // WAV header
    let audioFormat: UInt16 = 1 // PCM
    let numChannels: UInt16 = 1 // Mono
    let bitsPerSample: UInt16 = 16
    let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample) / 8)
    let blockAlign = UInt16(numChannels * bitsPerSample / 8)
    
    // RIFF header
    wavData.append("RIFF".data(using: .ascii)!)
    var chunkSize = UInt32(36 + pcmData.count)
    wavData.append(Data(bytes: &chunkSize, count: 4))
    wavData.append("WAVE".data(using: .ascii)!)
    
    // fmt subchunk
    wavData.append("fmt ".data(using: .ascii)!)
    var subchunk1Size: UInt32 = 16
    wavData.append(Data(bytes: &subchunk1Size, count: 4))
    var format = audioFormat
    wavData.append(Data(bytes: &format, count: 2))
    var channels = numChannels
    wavData.append(Data(bytes: &channels, count: 2))
    var sampleRateVar = UInt32(sampleRate)
    wavData.append(Data(bytes: &sampleRateVar, count: 4))
    var byteRateVar = byteRate
    wavData.append(Data(bytes: &byteRateVar, count: 4))
    var blockAlignVar = blockAlign
    wavData.append(Data(bytes: &blockAlignVar, count: 2))
    var bitsPerSampleVar = bitsPerSample
    wavData.append(Data(bytes: &bitsPerSampleVar, count: 2))
    
    // data subchunk
    wavData.append("data".data(using: .ascii)!)
    var dataSize = UInt32(pcmData.count)
    wavData.append(Data(bytes: &dataSize, count: 4))
    wavData.append(pcmData)
    
    return wavData
}
```

## Runtime Files

### Voice Models

Voice models can be downloaded from the [Piper repository](https://github.com/rhasspy/piper/releases). Each voice consists of:
- `*.onnx` - The neural network model
- `*.onnx.json` - Configuration file with phoneme mappings and audio settings

### espeak-ng-data

The `espeak-ng-data` directory is automatically generated during the build process and contains:
- Phoneme dictionaries for supported languages
- Intonation rules
- Voice configurations

For Android, this directory should be copied from the build output or extracted from the AAR assets at runtime.

For iOS, include the `espeak-ng-data` directory in your app bundle as a folder reference.

## CI/CD

The `.github/workflows/build-mobile.yml` workflow automatically builds both platforms on:
- Push to `main` branch (when mobile or libpiper files change)
- Pull requests (when mobile or libpiper files change)
- Manual trigger (`workflow_dispatch`)

### Artifacts

Build artifacts are uploaded to GitHub Actions:
- **Android**: `piper-android-aar` - Contains the AAR file
- **iOS**: `piper-ios-xcframework` - Contains the zipped XCFramework

Artifacts are retained for 30 days.

## Minimum Requirements

- **Android**: API 24 (Android 7.0) or higher, arm64-v8a devices
- **iOS**: iOS 15.0 or higher, arm64 devices (iPhone 6s and later)

## Notes

### Memory Usage

Piper TTS loads the entire ONNX model into memory. Typical voice models range from 30-100 MB. Ensure your app has sufficient memory available.

### Thread Safety

The Piper TTS API is not thread-safe. If you need to synthesize from multiple threads, create separate instances or use synchronization.

### Sample Rate

The sample rate depends on the voice model and is typically 22050 Hz. Use `getSampleRate()` (Android) or `sampleRateHz` (iOS) to get the correct value for audio playback.

### Error Handling

Both wrappers throw exceptions on errors:
- Android: `RuntimeException`
- iOS: `PiperError`

Always wrap TTS calls in try-catch blocks.

## Troubleshooting

### Android Build Issues

**Problem**: NDK not found
**Solution**: Install Android NDK r26 via SDK Manager:
```bash
sdkmanager --install "ndk;26.1.10909125"
```

**Problem**: CMake version mismatch
**Solution**: Update CMake in the SDK Manager or modify `build.gradle` to use an available version.

**Problem**: ONNX Runtime download fails
**Solution**: Check internet connection. The build script downloads ONNX Runtime AAR from Maven Central.

### iOS Build Issues

**Problem**: espeak-ng build fails
**Solution**: Ensure you have Xcode Command Line Tools installed:
```bash
xcode-select --install
```

**Problem**: ONNX Runtime not found
**Solution**: The build script downloads it automatically. Check internet connection and retry.

**Problem**: Code signing issues
**Solution**: XCFrameworks for distribution need to be signed. For development, disable code signing in Xcode project settings.

### Runtime Issues

**Problem**: `espeak_Initialize` fails
**Solution**: Verify the espeak-ng-data path is correct and the directory contains the required files.

**Problem**: ONNX model fails to load
**Solution**: Ensure the model file is compatible with ONNX Runtime 1.22.0 and is not corrupted.

**Problem**: Audio sounds distorted
**Solution**: Verify the sample rate matches between the synthesized audio and playback. Check for buffer overflow/underflow issues.

## License

Piper TTS is licensed under the GNU General Public License v3.0. See the main repository LICENSE file for details.

## Support

For issues and questions:
- [GitHub Issues](https://github.com/Zheng-Shuo/piper1-gpl/issues)
- [Piper Documentation](https://github.com/rhasspy/piper)
