#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include "piper.h"

#define LOG_TAG "PiperJNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_piper_tts_PiperTTS_nativeCreate(JNIEnv *env, jobject /* this */,
                                          jstring modelPath,
                                          jstring configPath,
                                          jstring espeakDataPath) {
    const char *model_path_str = env->GetStringUTFChars(modelPath, nullptr);
    const char *config_path_str = configPath ? env->GetStringUTFChars(configPath, nullptr) : nullptr;
    const char *espeak_data_path_str = env->GetStringUTFChars(espeakDataPath, nullptr);

    LOGI("Creating Piper synthesizer:");
    LOGI("  Model: %s", model_path_str);
    LOGI("  Config: %s", config_path_str ? config_path_str : "auto");
    LOGI("  Espeak data: %s", espeak_data_path_str);

    piper_synthesizer *synth = piper_create(model_path_str, config_path_str, espeak_data_path_str);

    env->ReleaseStringUTFChars(modelPath, model_path_str);
    if (config_path_str) {
        env->ReleaseStringUTFChars(configPath, config_path_str);
    }
    env->ReleaseStringUTFChars(espeakDataPath, espeak_data_path_str);

    if (!synth) {
        LOGE("Failed to create synthesizer");
        return 0;
    }

    LOGI("Synthesizer created successfully");
    return reinterpret_cast<jlong>(synth);
}

JNIEXPORT void JNICALL
Java_com_piper_tts_PiperTTS_nativeFree(JNIEnv *env, jobject /* this */, jlong handle) {
    piper_synthesizer *synth = reinterpret_cast<piper_synthesizer *>(handle);
    if (synth) {
        LOGI("Freeing synthesizer");
        piper_free(synth);
    }
}

JNIEXPORT jbyteArray JNICALL
Java_com_piper_tts_PiperTTS_nativeSynthesize(JNIEnv *env, jobject /* this */,
                                              jlong handle, jstring text) {
    piper_synthesizer *synth = reinterpret_cast<piper_synthesizer *>(handle);
    if (!synth) {
        LOGE("Invalid synthesizer handle");
        return nullptr;
    }

    const char *text_str = env->GetStringUTFChars(text, nullptr);
    LOGI("Synthesizing text: %s", text_str);

    // Start synthesis
    piper_synthesize_options options = piper_default_synthesize_options(synth);
    int result = piper_synthesize_start(synth, text_str, &options);
    env->ReleaseStringUTFChars(text, text_str);

    if (result != PIPER_OK) {
        LOGE("Failed to start synthesis");
        return nullptr;
    }

    // Collect all audio chunks
    std::vector<float> all_samples;
    piper_audio_chunk chunk;

    while (true) {
        result = piper_synthesize_next(synth, &chunk);
        if (result == PIPER_DONE) {
            break;
        }
        if (result != PIPER_OK) {
            LOGE("Error during synthesis");
            return nullptr;
        }

        // Append samples from this chunk
        if (chunk.samples && chunk.num_samples > 0) {
            all_samples.insert(all_samples.end(), chunk.samples,
                             chunk.samples + chunk.num_samples);
        }

        if (chunk.is_last) {
            break;
        }
    }

    LOGI("Synthesis complete, %zu samples", all_samples.size());

    // Convert float samples to 16-bit PCM
    std::vector<int16_t> pcm_samples;
    pcm_samples.reserve(all_samples.size());

    for (float sample : all_samples) {
        // Clamp to [-1.0, 1.0] and convert to int16
        sample = std::max(-1.0f, std::min(1.0f, sample));
        int16_t pcm_sample = static_cast<int16_t>(sample * 32767.0f);
        pcm_samples.push_back(pcm_sample);
    }

    // Create Java byte array (little-endian 16-bit PCM)
    jsize byte_length = pcm_samples.size() * 2;
    jbyteArray result_array = env->NewByteArray(byte_length);
    if (!result_array) {
        LOGE("Failed to allocate byte array");
        return nullptr;
    }

    env->SetByteArrayRegion(result_array, 0, byte_length,
                           reinterpret_cast<const jbyte *>(pcm_samples.data()));

    return result_array;
}

JNIEXPORT jint JNICALL
Java_com_piper_tts_PiperTTS_nativeGetSampleRate(JNIEnv *env, jobject /* this */, jlong handle) {
    piper_synthesizer *synth = reinterpret_cast<piper_synthesizer *>(handle);
    if (!synth) {
        LOGE("Invalid synthesizer handle");
        return 0;
    }

    // Start a dummy synthesis to get the sample rate
    piper_synthesize_options options = piper_default_synthesize_options(synth);
    int result = piper_synthesize_start(synth, " ", &options);
    if (result != PIPER_OK) {
        LOGE("Failed to start dummy synthesis for sample rate");
        return 22050; // Default fallback
    }

    piper_audio_chunk chunk;
    result = piper_synthesize_next(synth, &chunk);

    // Drain remaining chunks
    while (result != PIPER_DONE && result == PIPER_OK) {
        result = piper_synthesize_next(synth, &chunk);
    }

    int sample_rate = chunk.sample_rate;
    LOGI("Sample rate: %d Hz", sample_rate);
    return sample_rate;
}

} // extern "C"
