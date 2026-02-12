//
//  PiperTTS.swift
//  PiperTTS
//
//  Swift wrapper for Piper text-to-speech synthesis
//

import Foundation

/// Errors that can occur during Piper TTS operations
public enum PiperError: Error {
    case initializationFailed(String)
    case synthesisFailed(String)
    case invalidHandle
    case invalidParameters
}

/// Swift wrapper for Piper text-to-speech synthesis
///
/// This class provides a Swift-friendly interface to the libpiper C library,
/// enabling offline text-to-speech synthesis on iOS.
///
/// Example usage:
/// ```swift
/// let tts = try PiperTTS(
///     modelPath: modelPath,
///     configPath: configPath,
///     espeakDataPath: espeakDataPath
/// )
///
/// let audioData = try tts.synthesize(text: "Hello from Piper!")
/// let sampleRate = tts.sampleRate
/// // Play audioData at sampleRate
/// ```
public class PiperTTS {
    
    private var handle: OpaquePointer?
    
    /// Sample rate of the loaded voice model in Hz
    public private(set) var sampleRate: Int = 0
    
    /// Initialize a new Piper TTS synthesizer
    ///
    /// - Parameters:
    ///   - modelPath: Path to the ONNX voice model file (.onnx)
    ///   - configPath: Path to the voice config file (.onnx.json), or nil to auto-detect
    ///   - espeakDataPath: Path to the espeak-ng-data directory
    /// - Throws: `PiperError.initializationFailed` if initialization fails
    public init(modelPath: String, configPath: String?, espeakDataPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw PiperError.initializationFailed("Model file not found: \(modelPath)")
        }
        
        guard FileManager.default.fileExists(atPath: espeakDataPath) else {
            throw PiperError.initializationFailed("espeak-ng-data not found: \(espeakDataPath)")
        }
        
        let configPathC = configPath?.cString(using: .utf8)
        handle = piper_create(
            modelPath.cString(using: .utf8),
            configPathC,
            espeakDataPath.cString(using: .utf8)
        )
        
        guard handle != nil else {
            throw PiperError.initializationFailed(
                "Failed to create Piper synthesizer. Check paths and file validity."
            )
        }
        
        // Get sample rate by doing a test synthesis
        sampleRate = try getSampleRateInternal()
    }
    
    /// Synthesize text to 16-bit PCM audio data
    ///
    /// - Parameter text: The text to synthesize
    /// - Returns: Audio data as 16-bit little-endian PCM samples (mono)
    /// - Throws: `PiperError` if synthesis fails
    public func synthesize(text: String) throws -> Data {
        guard let handle = handle else {
            throw PiperError.invalidHandle
        }
        
        guard !text.isEmpty else {
            return Data()
        }
        
        // Get default options
        var options = piper_default_synthesize_options(handle)
        
        // Start synthesis
        let startResult = piper_synthesize_start(handle, text.cString(using: .utf8), &options)
        guard startResult == PIPER_OK else {
            throw PiperError.synthesisFailed("Failed to start synthesis")
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
                throw PiperError.synthesisFailed("Error during synthesis")
            }
            
            // Append samples from this chunk
            if let samples = chunk.samples, chunk.num_samples > 0 {
                let samplesArray = Array(UnsafeBufferPointer(start: samples, count: chunk.num_samples))
                allSamples.append(contentsOf: samplesArray)
            }
            
            if chunk.is_last {
                break
            }
        }
        
        // Convert float samples to 16-bit PCM
        var pcmData = Data(capacity: allSamples.count * 2)
        for sample in allSamples {
            // Clamp to [-1.0, 1.0] and convert to Int16
            let clampedSample = max(-1.0, min(1.0, sample))
            let pcmSample = Int16(clampedSample * 32767.0)
            
            // Append as little-endian
            var pcmSampleLE = pcmSample.littleEndian
            withUnsafeBytes(of: &pcmSampleLE) { bytes in
                pcmData.append(contentsOf: bytes)
            }
        }
        
        return pcmData
    }
    
    /// Synthesize text to float audio samples
    ///
    /// - Parameter text: The text to synthesize
    /// - Returns: Array of float audio samples (range: -1.0 to 1.0)
    /// - Throws: `PiperError` if synthesis fails
    public func synthesizeToFloat(text: String) throws -> [Float] {
        guard let handle = handle else {
            throw PiperError.invalidHandle
        }
        
        guard !text.isEmpty else {
            return []
        }
        
        // Get default options
        var options = piper_default_synthesize_options(handle)
        
        // Start synthesis
        let startResult = piper_synthesize_start(handle, text.cString(using: .utf8), &options)
        guard startResult == PIPER_OK else {
            throw PiperError.synthesisFailed("Failed to start synthesis")
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
                throw PiperError.synthesisFailed("Error during synthesis")
            }
            
            // Append samples from this chunk
            if let samples = chunk.samples, chunk.num_samples > 0 {
                let samplesArray = Array(UnsafeBufferPointer(start: samples, count: chunk.num_samples))
                allSamples.append(contentsOf: samplesArray)
            }
            
            if chunk.is_last {
                break
            }
        }
        
        return allSamples
    }
    
    /// Get the sample rate by performing a minimal synthesis
    private func getSampleRateInternal() throws -> Int {
        guard let handle = handle else {
            throw PiperError.invalidHandle
        }
        
        var options = piper_default_synthesize_options(handle)
        let result = piper_synthesize_start(handle, " ".cString(using: .utf8), &options)
        guard result == PIPER_OK else {
            return 22050 // Default fallback
        }
        
        var chunk = piper_audio_chunk()
        _ = piper_synthesize_next(handle, &chunk)
        
        // Drain remaining chunks
        while piper_synthesize_next(handle, &chunk) != PIPER_DONE {
            // Continue draining
        }
        
        return Int(chunk.sample_rate)
    }
    
    /// Cleanup native resources
    deinit {
        if let handle = handle {
            piper_free(handle)
        }
    }
}
