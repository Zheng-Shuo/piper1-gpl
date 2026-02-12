package com.piper.tts;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Java wrapper for Piper text-to-speech synthesis library.
 * 
 * This class provides a simple interface to the native libpiper library,
 * allowing Android applications to perform offline text-to-speech synthesis.
 * 
 * <p>Usage example:
 * <pre>
 * PiperTTS tts = new PiperTTS(modelPath, configPath, espeakDataPath);
 * short[] audio = tts.synthesize("Hello world!");
 * int sampleRate = tts.getSampleRate();
 * // Play audio samples at sampleRate
 * tts.release();
 * </pre>
 */
public class PiperTTS {
    static {
        System.loadLibrary("piper_jni");
    }

    private long nativeHandle = 0;
    private int sampleRate = 0;

    /**
     * Create a new Piper TTS synthesizer.
     * 
     * @param modelPath Path to the ONNX voice model file (.onnx)
     * @param configPath Path to the voice config file (.onnx.json), or null to auto-detect
     * @param espeakDataPath Path to the espeak-ng-data directory
     * @throws RuntimeException if initialization fails
     */
    public PiperTTS(String modelPath, String configPath, String espeakDataPath) {
        if (modelPath == null || espeakDataPath == null) {
            throw new IllegalArgumentException("modelPath and espeakDataPath cannot be null");
        }

        nativeHandle = nativeCreate(modelPath, configPath, espeakDataPath);
        if (nativeHandle == 0) {
            throw new RuntimeException("Failed to create Piper synthesizer. " +
                    "Check that model, config, and espeak-ng-data paths are valid.");
        }

        sampleRate = nativeGetSampleRate(nativeHandle);
    }

    /**
     * Synthesize text to audio samples.
     * 
     * @param text The text to synthesize
     * @return Array of 16-bit PCM audio samples (mono)
     * @throws RuntimeException if synthesis fails
     */
    public short[] synthesize(String text) {
        if (nativeHandle == 0) {
            throw new IllegalStateException("PiperTTS has been released");
        }
        if (text == null || text.isEmpty()) {
            return new short[0];
        }

        byte[] audioBytes = nativeSynthesize(nativeHandle, text);
        if (audioBytes == null) {
            throw new RuntimeException("Failed to synthesize text");
        }

        // Convert byte array to short array (16-bit PCM)
        short[] audioSamples = new short[audioBytes.length / 2];
        ByteBuffer.wrap(audioBytes)
                .order(ByteOrder.LITTLE_ENDIAN)
                .asShortBuffer()
                .get(audioSamples);

        return audioSamples;
    }

    /**
     * Get the sample rate of the loaded voice model.
     * 
     * @return Sample rate in Hz (typically 16000 or 22050)
     */
    public int getSampleRate() {
        return sampleRate;
    }

    /**
     * Release native resources.
     * 
     * Must be called when done using this PiperTTS instance.
     * After calling release(), this instance cannot be used anymore.
     * 
     * It is recommended to use this class in a try-finally block:
     * <pre>
     * PiperTTS tts = null;
     * try {
     *     tts = new PiperTTS(modelPath, configPath, espeakDataPath);
     *     // Use tts...
     * } finally {
     *     if (tts != null) {
     *         tts.release();
     *     }
     * }
     * </pre>
     */
    public void release() {
        if (nativeHandle != 0) {
            nativeFree(nativeHandle);
            nativeHandle = 0;
        }
    }

    // Native methods
    private native long nativeCreate(String modelPath, String configPath, String espeakDataPath);
    private native void nativeFree(long handle);
    private native byte[] nativeSynthesize(long handle, String text);
    private native int nativeGetSampleRate(long handle);
}
