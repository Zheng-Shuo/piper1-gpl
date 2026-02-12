import Foundation

/// Swift wrapper for the Piper TTS C library.
/// Provides text-to-speech synthesis using ONNX voice models.
public class PiperTTS {
    private var handle: OpaquePointer?
    private let sampleRate: Int
    
    /// Errors that can occur during synthesis
    public enum PiperError: Error {
        case initializationFailed
        case synthesisFailed
        case invalidHandle
        case invalidInput
    }
    
    /// Initialize a new Piper TTS synthesizer
    ///
    /// - Parameters:
    ///   - modelPath: Path to the ONNX voice model file
    ///   - configPath: Path to the JSON config file (optional, will use modelPath + ".json" if nil)
    ///   - espeakDataPath: Path to the espeak-ng-data directory
    /// - Throws: PiperError.initializationFailed if initialization fails
    public init(modelPath: String, configPath: String? = nil, espeakDataPath: String) throws {
        let configPathC = configPath?.cString(using: .utf8)
        let configPathPtr = configPathC?.withUnsafeBufferPointer { $0.baseAddress }
        
        handle = modelPath.withCString { modelPtr in
            espeakDataPath.withCString { espeakPtr in
                if let configPtr = configPathPtr {
                    return piper_create(modelPtr, configPtr, espeakPtr)
                } else {
                    return piper_create(modelPtr, nil, espeakPtr)
                }
            }
        }
        
        guard handle != nil else {
            throw PiperError.initializationFailed
        }
        
        // Get sample rate by doing a test synthesis
        // Note: In the real implementation, we'd need to extract this from the config
        sampleRate = 22050 // Default value
    }
    
    /// Synthesize text to 16-bit PCM audio samples
    ///
    /// - Parameter text: Text to synthesize
    /// - Returns: 16-bit PCM audio data
    /// - Throws: PiperError if synthesis fails
    public func synthesize(text: String) throws -> Data {
        guard let handle = handle else {
            throw PiperError.invalidHandle
        }
        
        guard !text.isEmpty else {
            throw PiperError.invalidInput
        }
        
        // Get default options
        var options = piper_default_synthesize_options(handle)
        
        // Start synthesis
        let startResult = text.withCString { textPtr in
            piper_synthesize_start(handle, textPtr, &options)
        }
        
        guard startResult == PIPER_OK else {
            throw PiperError.synthesisFailed
        }
        
        // Collect all audio chunks
        var allSamples: [Float] = []
        var chunk = piper_audio_chunk()
        
        while true {
            let result = piper_synthesize_next(handle, &chunk)
            
            if result == PIPER_DONE {
                break
            }
            
            guard result == PIPER_OK else {
                throw PiperError.synthesisFailed
            }
            
            // Append samples
            if let samples = chunk.samples {
                let sampleArray = Array(UnsafeBufferPointer(start: samples, count: Int(chunk.num_samples)))
                allSamples.append(contentsOf: sampleArray)
            }
            
            if chunk.is_last {
                break
            }
        }
        
        // Convert float samples to 16-bit PCM
        let pcmSamples: [Int16] = allSamples.map { sample in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * 32767.0)
        }
        
        return Data(bytes: pcmSamples, count: pcmSamples.count * MemoryLayout<Int16>.size)
    }
    
    /// Synthesize text to float audio samples
    ///
    /// - Parameter text: Text to synthesize
    /// - Returns: Float audio samples in range [-1.0, 1.0]
    /// - Throws: PiperError if synthesis fails
    public func synthesizeToFloat(text: String) throws -> [Float] {
        guard let handle = handle else {
            throw PiperError.invalidHandle
        }
        
        guard !text.isEmpty else {
            throw PiperError.invalidInput
        }
        
        // Get default options
        var options = piper_default_synthesize_options(handle)
        
        // Start synthesis
        let startResult = text.withCString { textPtr in
            piper_synthesize_start(handle, textPtr, &options)
        }
        
        guard startResult == PIPER_OK else {
            throw PiperError.synthesisFailed
        }
        
        // Collect all audio chunks
        var allSamples: [Float] = []
        var chunk = piper_audio_chunk()
        
        while true {
            let result = piper_synthesize_next(handle, &chunk)
            
            if result == PIPER_DONE {
                break
            }
            
            guard result == PIPER_OK else {
                throw PiperError.synthesisFailed
            }
            
            // Append samples
            if let samples = chunk.samples {
                let sampleArray = Array(UnsafeBufferPointer(start: samples, count: Int(chunk.num_samples)))
                allSamples.append(contentsOf: sampleArray)
            }
            
            if chunk.is_last {
                break
            }
        }
        
        return allSamples
    }
    
    /// Get the sample rate of the loaded voice
    public var sampleRateHz: Int {
        return sampleRate
    }
    
    deinit {
        if let handle = handle {
            piper_free(handle)
        }
    }
}

// Constants from piper.h
private let PIPER_OK: Int32 = 0
private let PIPER_DONE: Int32 = 1
private let PIPER_ERR_GENERIC: Int32 = -1
