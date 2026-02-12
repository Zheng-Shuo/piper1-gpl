# 📱 Piper Mobile Platform Support

> [中文版](README_CN.md)

This directory contains build configurations and wrapper libraries for using Piper on mobile platforms (Android and iOS).

## Overview

The mobile builds provide native bindings for the `libpiper` C API, enabling offline text-to-speech synthesis on Android and iOS devices.

**Key Features:**
- ✅ Offline TTS - no internet required
- ✅ Cross-platform C API wrapper
- ✅ Native performance via ONNX Runtime
- ✅ Comprehensive phoneme alignment data
- ✅ Multi-speaker model support

## Platform Support

| Platform | Architecture | Min Version | Build Output |
|----------|-------------|-------------|--------------|
| Android  | arm64-v8a   | API 24      | AAR package  |
| iOS      | arm64       | iOS 15.0    | XCFramework  |

## Dependencies

Both platforms include:
- **libpiper** - C/C++ shared library
- **espeak-ng** - Phonemization engine (static library)
- **ONNX Runtime 1.22.0** - Neural network inference
- **nlohmann/json** - JSON parsing (header-only)
- **uni_algo** - Unicode algorithms (header-only)

---

## Android Integration

### Building the AAR

#### Prerequisites
- JDK 17 or later
- Android SDK with NDK r26d or later
- Gradle 8.x

#### Build Steps

1. Navigate to the Android project directory:
   ```bash
   cd mobile/android
   ```

2. Build the AAR:
   ```bash
   ./gradlew :piper:assembleRelease
   ```

3. The AAR will be located at:
   ```
   mobile/android/piper/build/outputs/aar/piper-release.aar
   ```

### Using the AAR in Your App

#### 1. Add the AAR to Your Project

Copy `piper-release.aar` to your app's `libs/` directory, then add to your `build.gradle`:

```gradle
dependencies {
    implementation files('libs/piper-release.aar')
    implementation 'com.microsoft.onnxruntime:onnxruntime-android:1.22.0'
}
```

#### 2. Copy espeak-ng Data to Assets

The `espeak-ng-data` directory must be included in your app's assets. At runtime, copy it to internal storage:

```java
private String copyEspeakDataToInternalStorage(Context context) throws IOException {
    File espeakDir = new File(context.getFilesDir(), "espeak-ng-data");
    if (!espeakDir.exists()) {
        AssetManager assetManager = context.getAssets();
        copyAssetFolder(assetManager, "espeak-ng-data", espeakDir.getAbsolutePath());
    }
    return espeakDir.getAbsolutePath();
}

private void copyAssetFolder(AssetManager assetManager, String srcName, String dstName) throws IOException {
    String[] files = assetManager.list(srcName);
    File outFile = new File(dstName);
    if (!outFile.exists() && files.length == 0) {
        // It's a file
        copyAssetFile(assetManager, srcName, dstName);
    } else {
        // It's a directory
        outFile.mkdirs();
        for (String filename : files) {
            copyAssetFolder(assetManager, srcName + "/" + filename, dstName + "/" + filename);
        }
    }
}

private void copyAssetFile(AssetManager assetManager, String srcName, String dstName) throws IOException {
    InputStream in = assetManager.open(srcName);
    OutputStream out = new FileOutputStream(dstName);
    byte[] buffer = new byte[1024];
    int read;
    while ((read = in.read(buffer)) != -1) {
        out.write(buffer, 0, read);
    }
    in.close();
    out.close();
}
```

#### 3. Initialize and Use PiperTTS

```java
import com.piper.tts.PiperTTS;
import java.io.File;

public class MainActivity extends AppCompatActivity {
    private PiperTTS piperTTS;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        try {
            // Copy espeak data to internal storage
            String espeakDataPath = copyEspeakDataToInternalStorage(this);
            
            // Copy model and config to internal storage (or download them)
            File modelFile = new File(getFilesDir(), "voice.onnx");
            File configFile = new File(getFilesDir(), "voice.onnx.json");
            // ... copy model and config files ...
            
            // Initialize Piper
            piperTTS = new PiperTTS(
                modelFile.getAbsolutePath(),
                configFile.getAbsolutePath(),
                espeakDataPath
            );
            
            // Synthesize speech
            short[] audioSamples = piperTTS.synthesize("Hello from Piper!");
            int sampleRate = piperTTS.getSampleRate();
            
            // Play audio samples at the specified sample rate
            playAudio(audioSamples, sampleRate);
            
        } catch (Exception e) {
            Log.e("Piper", "Error initializing TTS", e);
        }
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (piperTTS != null) {
            piperTTS.release();
        }
    }
    
    private void playAudio(short[] samples, int sampleRate) {
        // Use AudioTrack or MediaPlayer to play the PCM samples
        int bufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        );
        
        AudioTrack audioTrack = new AudioTrack(
            AudioManager.STREAM_MUSIC,
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize,
            AudioTrack.MODE_STREAM
        );
        
        audioTrack.play();
        audioTrack.write(samples, 0, samples.length);
        audioTrack.stop();
        audioTrack.release();
    }
}
```

#### 4. Required Permissions

Add to `AndroidManifest.xml` if writing to external storage:
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

---

## iOS Integration

### Building the XCFramework

#### Prerequisites
- macOS 14+ (Apple Silicon recommended)
- Xcode 15.0 or later
- CMake 3.26 or later

#### Build Steps

1. Navigate to the iOS directory:
   ```bash
   cd mobile/ios
   ```

2. Run the build script:
   ```bash
   chmod +x build_xcframework.sh
   ./build_xcframework.sh
   ```

3. The XCFramework will be located at:
   ```
   mobile/ios/build/PiperTTS.xcframework
   ```

### Using the XCFramework in Your App

#### 1. Add the XCFramework to Your Project

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to "General" → "Frameworks, Libraries, and Embedded Content"
4. Click "+" and add `PiperTTS.xcframework`
5. Set "Embed" to "Embed & Sign"

#### 2. Add ONNX Runtime Dependency

Add the ONNX Runtime iOS framework (1.22.0) via CocoaPods:

```ruby
# Podfile
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!
  pod 'onnxruntime-c', '~> 1.22.0'
end
```

Or download manually from [ONNX Runtime releases](https://github.com/microsoft/onnxruntime/releases).

#### 3. Bundle espeak-ng Data

1. Copy the `espeak-ng-data` directory to your app bundle
2. In Xcode, add the folder to your project (select "Create folder references")
3. Ensure it's included in "Copy Bundle Resources" build phase

#### 4. Initialize and Use PiperTTS

```swift
import PiperTTS
import AVFoundation

class SpeechSynthesizer {
    private var piperTTS: PiperTTS?
    private var audioEngine: AVAudioEngine?
    
    func initialize() throws {
        // Get paths from bundle
        guard let modelPath = Bundle.main.path(forResource: "voice", ofType: "onnx"),
              let configPath = Bundle.main.path(forResource: "voice.onnx", ofType: "json"),
              let espeakDataPath = Bundle.main.path(forResource: "espeak-ng-data", ofType: nil)
        else {
            throw NSError(domain: "PiperError", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Required resources not found"])
        }
        
        // Initialize Piper
        piperTTS = try PiperTTS(
            modelPath: modelPath,
            configPath: configPath,
            espeakDataPath: espeakDataPath
        )
    }
    
    func synthesize(text: String) throws -> Data {
        guard let piperTTS = piperTTS else {
            throw NSError(domain: "PiperError", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "PiperTTS not initialized"])
        }
        
        // Returns 16-bit PCM audio data
        return try piperTTS.synthesize(text: text)
    }
    
    func synthesizeToFloat(text: String) throws -> [Float] {
        guard let piperTTS = piperTTS else {
            throw NSError(domain: "PiperError", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "PiperTTS not initialized"])
        }
        
        // Returns float samples for advanced audio processing
        return try piperTTS.synthesizeToFloat(text: text)
    }
    
    func playAudio(pcmData: Data, sampleRate: Int) throws {
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        audioEngine.attach(playerNode)
        
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        )!
        
        let audioBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: UInt32(pcmData.count / 2)
        )!
        
        audioBuffer.frameLength = audioBuffer.frameCapacity
        
        pcmData.withUnsafeBytes { bytes in
            let samples = bytes.bindMemory(to: Int16.self)
            let channelData = audioBuffer.int16ChannelData![0]
            for i in 0..<Int(audioBuffer.frameLength) {
                channelData[i] = samples[i]
            }
        }
        
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        
        try audioEngine.start()
        playerNode.play()
        playerNode.scheduleBuffer(audioBuffer, completionHandler: nil)
    }
    
    deinit {
        // PiperTTS cleanup is handled automatically via deinit
    }
}

// Usage example
do {
    let synthesizer = SpeechSynthesizer()
    try synthesizer.initialize()
    
    let text = "Hello from Piper on iOS!"
    let audioData = try synthesizer.synthesize(text: text)
    let sampleRate = synthesizer.piperTTS?.sampleRate ?? 22050
    
    try synthesizer.playAudio(pcmData: audioData, sampleRate: sampleRate)
} catch {
    print("Error: \(error)")
}
```

---

## Runtime Requirements

### Model Files

Both platforms require the following files at runtime:

1. **Voice Model** (`.onnx` file)
   - Download from [Piper Voices](https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/VOICES.md)
   - Typically 5-60 MB depending on quality

2. **Voice Config** (`.onnx.json` file)
   - Included with model download
   - Contains metadata and synthesis parameters

3. **espeak-ng-data** (directory)
   - Included in both AAR and XCFramework builds
   - Contains phoneme dictionaries for 100+ languages
   - ~5 MB compressed

### Storage Recommendations

- **Android**: Copy model files to internal storage (`getFilesDir()`) or external storage
- **iOS**: Bundle model files in app bundle or download on first launch
- Both: Consider using on-demand resources for large model collections

### Memory Usage

Typical memory footprint:
- Model loading: 10-80 MB (depends on model size)
- Inference: 5-20 MB per synthesis
- espeak-ng: ~2 MB

---

## API Reference

### Android (Java)

```java
// Constructor
PiperTTS(String modelPath, String configPath, String espeakDataPath)

// Methods
short[] synthesize(String text)  // Returns 16-bit PCM samples
int getSampleRate()               // Returns sample rate in Hz
void release()                    // Free native resources
```

### iOS (Swift)

```swift
// Constructor
init(modelPath: String, configPath: String?, espeakDataPath: String) throws

// Methods
func synthesize(text: String) throws -> Data        // Returns 16-bit PCM data
func synthesizeToFloat(text: String) throws -> [Float]  // Returns float samples
var sampleRate: Int                                 // Sample rate in Hz

// Automatic cleanup via deinit
```

---

## Troubleshooting

### Android

**Issue**: `UnsatisfiedLinkError` when loading native library
- **Solution**: Ensure ONNX Runtime dependency is included in `build.gradle`
- **Solution**: Check that the AAR architecture matches your device (arm64-v8a)

**Issue**: `FileNotFoundException` for espeak-ng-data
- **Solution**: Verify espeak data was copied to internal storage correctly
- **Solution**: Check file permissions

**Issue**: Synthesis produces no audio or crashes
- **Solution**: Verify model and config file paths are correct
- **Solution**: Ensure model is compatible with ONNX Runtime 1.22.0
- **Solution**: Check logcat for native crash details

### iOS

**Issue**: Framework not found or linker errors
- **Solution**: Ensure PiperTTS.xcframework is properly embedded
- **Solution**: Add ONNX Runtime framework via CocoaPods or manually

**Issue**: Resources not found at runtime
- **Solution**: Verify espeak-ng-data is in app bundle
- **Solution**: Check bundle paths using `Bundle.main.path(forResource:ofType:)`

**Issue**: App crashes on device but works in simulator
- **Solution**: XCFramework currently supports arm64 device only (not simulator)
- **Solution**: Build must be done on Apple Silicon Mac for device testing

---

## Performance Tips

1. **Reuse synthesizer instances** - Creating a synthesizer is expensive (model loading)
2. **Batch synthesis** - Process multiple sentences in sequence rather than recreating synthesizer
3. **Background threads** - Run synthesis on a background thread to avoid blocking UI
4. **Audio buffering** - Use appropriate buffer sizes for smooth audio playback
5. **Model selection** - Smaller models (10-20 MB) work well for most languages; use larger models only when needed

---

## Supported Languages

espeak-ng includes phoneme support for 100+ languages. Some examples:

- English (en-us, en-gb)
- Spanish (es)
- French (fr-fr)
- German (de)
- Italian (it)
- Portuguese (pt-br)
- Russian (ru)
- Chinese (cmn)
- Japanese (ja)
- Korean (ko)
- Arabic (ar)
- And many more...

For a complete list, see the [espeak-ng language documentation](https://github.com/espeak-ng/espeak-ng/blob/master/docs/languages.md).

---

## Building from Source

See individual platform directories for detailed build instructions:
- [Android Build Guide](android/README.md) (TODO)
- [iOS Build Guide](ios/README.md) (TODO)

---

## License

Piper is licensed under the GPL v3.0. See [COPYING](../COPYING) for details.

Mobile platform bindings maintain the same license.

---

## Contributing

Contributions are welcome! Please:
1. Test on physical devices (not just emulators/simulators)
2. Follow existing code style
3. Add documentation for new features
4. Report issues with device/OS version details

---

## Support

For issues and questions:
- GitHub Issues: [Piper Issues](https://github.com/Zheng-Shuo/piper1-gpl/issues)
- Documentation: [Piper Docs](https://github.com/OHF-Voice/piper1-gpl/tree/main/docs)

---

## Acknowledgments

- [espeak-ng](https://github.com/espeak-ng/espeak-ng) - Phonemization engine
- [ONNX Runtime](https://github.com/microsoft/onnxruntime) - Neural network inference
- [Piper](https://github.com/rhasspy/piper) - Original project by Rhasspy
- [Open Home Foundation](https://www.openhomefoundation.org/) - Project maintainer
