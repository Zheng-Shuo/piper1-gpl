package com.piper.tts;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Java wrapper for the Piper TTS C library.
 * Provides text-to-speech synthesis using ONNX voice models.
 */
public class PiperTTS {
    private long nativeHandle = 0;
    private int sampleRate = 0;

    static {
        System.loadLibrary("piper_jni");
    }

    /**
     * Create a new Piper TTS synthesizer.
     *
     * @param modelPath Path to the ONNX voice model file
     * @param configPath Path to the JSON config file (or null to use modelPath + ".json")
     * @param espeakDataPath Path to the espeak-ng-data directory
     * @throws RuntimeException if initialization fails
     */
    public PiperTTS(@NonNull String modelPath, @Nullable String configPath, @NonNull String espeakDataPath) {
        nativeHandle = nativeCreate(modelPath, configPath, espeakDataPath);
        if (nativeHandle == 0) {
            throw new RuntimeException("Failed to create Piper synthesizer");
        }
        sampleRate = nativeGetSampleRate(nativeHandle);
    }

    /**
     * Synthesize text to 16-bit PCM audio samples.
     *
     * @param text Text to synthesize
     * @return 16-bit PCM audio samples
     * @throws RuntimeException if synthesis fails
     */
    @NonNull
    public short[] synthesize(@NonNull String text) {
        if (nativeHandle == 0) {
            throw new IllegalStateException("Synthesizer has been released");
        }
        short[] result = nativeSynthesize(nativeHandle, text);
        if (result == null) {
            throw new RuntimeException("Synthesis failed");
        }
        return result;
    }

    /**
     * Get the sample rate of the loaded voice.
     *
     * @return Sample rate in Hz
     */
    public int getSampleRate() {
        return sampleRate;
    }

    /**
     * Release native resources. After calling this method, the object cannot be used.
     */
    public void release() {
        if (nativeHandle != 0) {
            nativeFree(nativeHandle);
            nativeHandle = 0;
        }
    }

    @Override
    protected void finalize() throws Throwable {
        try {
            release();
        } finally {
            super.finalize();
        }
    }

    // Native methods
    private native long nativeCreate(String modelPath, String configPath, String espeakDataPath);
    private native void nativeFree(long handle);
    private native short[] nativeSynthesize(long handle, String text);
    private native int nativeGetSampleRate(long handle);
}
