# 📱 Piper 移动端平台支持

> [English Version](README.md)

本目录包含在移动平台（Android 和 iOS）上使用 Piper 的编译配置和封装库。

## 概述

移动端编译为 `libpiper` C API 提供了原生绑定，可在 Android 和 iOS 设备上实现离线文本转语音合成。

**主要特性：**
- ✅ 离线 TTS - 无需联网
- ✅ 跨平台 C API 封装
- ✅ 通过 ONNX Runtime 获得原生性能
- ✅ 完整的音素对齐数据
- ✅ 多说话人模型支持

## 平台支持

| 平台 | 架构 | 最低版本 | 编译输出 |
|----------|-------------|-------------|--------------|
| Android  | arm64-v8a   | API 24      | AAR 包  |
| iOS      | arm64       | iOS 15.0    | XCFramework  |

## 依赖项

两个平台都包含：
- **libpiper** - C/C++ 共享库
- **espeak-ng** - 音素化引擎（静态库）
- **ONNX Runtime 1.22.0** - 神经网络推理
- **nlohmann/json** - JSON 解析（仅头文件）
- **uni_algo** - Unicode 算法（仅头文件）

---

## Android 集成

### 编译 AAR

#### 前提条件
- JDK 17 或更高版本
- Android SDK 和 NDK r26d 或更高版本
- Gradle 8.x

#### 编译步骤

1. 进入 Android 项目目录：
   ```bash
   cd mobile/android
   ```

2. 编译 AAR：
   ```bash
   ./gradlew :piper:assembleRelease
   ```

3. AAR 文件位置：
   ```
   mobile/android/piper/build/outputs/aar/piper-release.aar
   ```

### 在您的应用中使用 AAR

#### 1. 将 AAR 添加到项目

将 `piper-release.aar` 复制到应用的 `libs/` 目录，然后在 `build.gradle` 中添加：

```gradle
dependencies {
    implementation files('libs/piper-release.aar')
    implementation 'com.microsoft.onnxruntime:onnxruntime-android:1.22.0'
}
```

#### 2. 将 espeak-ng 数据复制到资源目录

`espeak-ng-data` 目录必须包含在应用的资源中。在运行时，将其复制到内部存储：

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
        // 这是一个文件
        copyAssetFile(assetManager, srcName, dstName);
    } else {
        // 这是一个目录
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

#### 3. 初始化和使用 PiperTTS

```java
import com.piper.tts.PiperTTS;
import java.io.File;

public class MainActivity extends AppCompatActivity {
    private PiperTTS piperTTS;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        try {
            // 将 espeak 数据复制到内部存储
            String espeakDataPath = copyEspeakDataToInternalStorage(this);
            
            // 将模型和配置文件复制到内部存储（或下载它们）
            File modelFile = new File(getFilesDir(), "voice.onnx");
            File configFile = new File(getFilesDir(), "voice.onnx.json");
            // ... 复制模型和配置文件 ...
            
            // 初始化 Piper
            piperTTS = new PiperTTS(
                modelFile.getAbsolutePath(),
                configFile.getAbsolutePath(),
                espeakDataPath
            );
            
            // 合成语音
            short[] audioSamples = piperTTS.synthesize("你好，来自 Piper！");
            int sampleRate = piperTTS.getSampleRate();
            
            // 以指定的采样率播放音频样本
            playAudio(audioSamples, sampleRate);
            
        } catch (Exception e) {
            Log.e("Piper", "初始化 TTS 时出错", e);
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
        // 使用 AudioTrack 或 MediaPlayer 播放 PCM 样本
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

#### 4. 所需权限

如果要写入外部存储，请添加到 `AndroidManifest.xml`：
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

---

## iOS 集成

### 编译 XCFramework

#### 前提条件
- macOS 14+（推荐使用 Apple Silicon）
- Xcode 15.0 或更高版本
- CMake 3.26 或更高版本

#### 编译步骤

1. 进入 iOS 目录：
   ```bash
   cd mobile/ios
   ```

2. 运行编译脚本：
   ```bash
   chmod +x build_xcframework.sh
   ./build_xcframework.sh
   ```

3. XCFramework 位置：
   ```
   mobile/ios/build/PiperTTS.xcframework
   ```

### 在您的应用中使用 XCFramework

#### 1. 将 XCFramework 添加到项目

1. 在 Xcode 中，在导航器中选择您的项目
2. 选择您的应用 target
3. 转到"General"→"Frameworks, Libraries, and Embedded Content"
4. 点击"+"并添加 `PiperTTS.xcframework`
5. 将"Embed"设置为"Embed & Sign"

#### 2. 添加 ONNX Runtime 依赖

通过 CocoaPods 添加 ONNX Runtime iOS 框架（1.22.0）：

```ruby
# Podfile
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!
  pod 'onnxruntime-c', '~> 1.22.0'
end
```

或从 [ONNX Runtime 发布页面](https://github.com/microsoft/onnxruntime/releases)手动下载。

#### 3. 打包 espeak-ng 数据

1. 将 `espeak-ng-data` 目录复制到应用包中
2. 在 Xcode 中，将文件夹添加到项目（选择"Create folder references"）
3. 确保它包含在"Copy Bundle Resources"构建阶段中

#### 4. 初始化和使用 PiperTTS

```swift
import PiperTTS
import AVFoundation

class SpeechSynthesizer {
    private var piperTTS: PiperTTS?
    private var audioEngine: AVAudioEngine?
    
    func initialize() throws {
        // 从 bundle 获取路径
        guard let modelPath = Bundle.main.path(forResource: "voice", ofType: "onnx"),
              let configPath = Bundle.main.path(forResource: "voice.onnx", ofType: "json"),
              let espeakDataPath = Bundle.main.path(forResource: "espeak-ng-data", ofType: nil)
        else {
            throw NSError(domain: "PiperError", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "找不到所需资源"])
        }
        
        // 初始化 Piper
        piperTTS = try PiperTTS(
            modelPath: modelPath,
            configPath: configPath,
            espeakDataPath: espeakDataPath
        )
    }
    
    func synthesize(text: String) throws -> Data {
        guard let piperTTS = piperTTS else {
            throw NSError(domain: "PiperError", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "PiperTTS 未初始化"])
        }
        
        // 返回 16 位 PCM 音频数据
        return try piperTTS.synthesize(text: text)
    }
    
    func synthesizeToFloat(text: String) throws -> [Float] {
        guard let piperTTS = piperTTS else {
            throw NSError(domain: "PiperError", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "PiperTTS 未初始化"])
        }
        
        // 返回浮点样本用于高级音频处理
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
        // PiperTTS 清理通过 deinit 自动处理
    }
}

// 使用示例
do {
    let synthesizer = SpeechSynthesizer()
    try synthesizer.initialize()
    
    let text = "你好，来自 iOS 上的 Piper！"
    let audioData = try synthesizer.synthesize(text: text)
    let sampleRate = synthesizer.piperTTS?.sampleRate ?? 22050
    
    try synthesizer.playAudio(pcmData: audioData, sampleRate: sampleRate)
} catch {
    print("错误：\(error)")
}
```

---

## 运行时要求

### 模型文件

两个平台在运行时都需要以下文件：

1. **语音模型**（`.onnx` 文件）
   - 从 [Piper Voices](https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/VOICES.md) 下载
   - 根据质量不同通常为 5-60 MB

2. **语音配置**（`.onnx.json` 文件）
   - 随模型下载一起提供
   - 包含元数据和合成参数

3. **espeak-ng-data**（目录）
   - 包含在 AAR 和 XCFramework 编译中
   - 包含 100 多种语言的音素词典
   - 压缩后约 5 MB

### 存储建议

- **Android**：将模型文件复制到内部存储（`getFilesDir()`）或外部存储
- **iOS**：将模型文件打包在应用包中或在首次启动时下载
- 两者：对于大型模型集合，考虑使用按需资源

### 内存使用

典型内存占用：
- 模型加载：10-80 MB（取决于模型大小）
- 推理：每次合成 5-20 MB
- espeak-ng：约 2 MB

---

## API 参考

### Android (Java)

```java
// 构造函数
PiperTTS(String modelPath, String configPath, String espeakDataPath)

// 方法
short[] synthesize(String text)  // 返回 16 位 PCM 样本
int getSampleRate()               // 返回采样率（Hz）
void release()                    // 释放原生资源
```

### iOS (Swift)

```swift
// 构造函数
init(modelPath: String, configPath: String?, espeakDataPath: String) throws

// 方法
func synthesize(text: String) throws -> Data        // 返回 16 位 PCM 数据
func synthesizeToFloat(text: String) throws -> [Float]  // 返回浮点样本
var sampleRate: Int                                 // 采样率（Hz）

// 通过 deinit 自动清理
```

---

## 故障排查

### Android

**问题**：加载原生库时出现 `UnsatisfiedLinkError`
- **解决方案**：确保在 `build.gradle` 中包含 ONNX Runtime 依赖项
- **解决方案**：检查 AAR 架构是否与您的设备匹配（arm64-v8a）

**问题**：espeak-ng-data 出现 `FileNotFoundException`
- **解决方案**：验证 espeak 数据是否正确复制到内部存储
- **解决方案**：检查文件权限

**问题**：合成没有产生音频或崩溃
- **解决方案**：验证模型和配置文件路径是否正确
- **解决方案**：确保模型与 ONNX Runtime 1.22.0 兼容
- **解决方案**：检查 logcat 以了解原生崩溃详细信息

### iOS

**问题**：找不到框架或链接器错误
- **解决方案**：确保 PiperTTS.xcframework 已正确嵌入
- **解决方案**：通过 CocoaPods 或手动添加 ONNX Runtime 框架

**问题**：运行时找不到资源
- **解决方案**：验证 espeak-ng-data 是否在应用包中
- **解决方案**：使用 `Bundle.main.path(forResource:ofType:)` 检查包路径

**问题**：应用在设备上崩溃但在模拟器上正常工作
- **解决方案**：XCFramework 目前仅支持 arm64 设备（不支持模拟器）
- **解决方案**：必须在 Apple Silicon Mac 上编译才能进行设备测试

---

## 性能建议

1. **重用合成器实例** - 创建合成器成本高昂（模型加载）
2. **批量合成** - 按顺序处理多个句子而不是重新创建合成器
3. **后台线程** - 在后台线程上运行合成以避免阻塞 UI
4. **音频缓冲** - 使用适当的缓冲区大小以实现流畅的音频播放
5. **模型选择** - 较小的模型（10-20 MB）适用于大多数语言；仅在需要时使用较大的模型

---

## 支持的语言

espeak-ng 包含对 100 多种语言的音素支持。一些示例：

- 英语（en-us、en-gb）
- 西班牙语（es）
- 法语（fr-fr）
- 德语（de）
- 意大利语（it）
- 葡萄牙语（pt-br）
- 俄语（ru）
- 中文（cmn）
- 日语（ja）
- 韩语（ko）
- 阿拉伯语（ar）
- 以及更多...

有关完整列表，请参阅 [espeak-ng 语言文档](https://github.com/espeak-ng/espeak-ng/blob/master/docs/languages.md)。

---

## 从源代码编译

有关详细的编译说明，请参阅各个平台目录：
- [Android 编译指南](android/README.md)（待办）
- [iOS 编译指南](ios/README.md)（待办）

---

## 许可证

Piper 基于 GPL v3.0 许可。详情请参阅 [COPYING](../COPYING)。

移动平台绑定保持相同的许可证。

---

## 贡献

欢迎贡献！请：
1. 在物理设备上测试（不仅仅是模拟器）
2. 遵循现有代码风格
3. 为新功能添加文档
4. 报告问题时附带设备/操作系统版本详细信息

---

## 支持

如有问题和疑问：
- GitHub Issues：[Piper Issues](https://github.com/Zheng-Shuo/piper1-gpl/issues)
- 文档：[Piper Docs](https://github.com/OHF-Voice/piper1-gpl/tree/main/docs)

---

## 致谢

- [espeak-ng](https://github.com/espeak-ng/espeak-ng) - 音素化引擎
- [ONNX Runtime](https://github.com/microsoft/onnxruntime) - 神经网络推理
- [Piper](https://github.com/rhasspy/piper) - Rhasspy 的原始项目
- [Open Home Foundation](https://www.openhomefoundation.org/) - 项目维护者
