#include <jni.h>
#include <vector>
#include <string>
#include <android/log.h>

#include "piper.h"

#define LOG_TAG "PiperJNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_piper_tts_PiperTTS_nativeCreate(JNIEnv *env, jobject thiz,
                                         jstring modelPath, jstring configPath,
                                         jstring espeakDataPath) {
    const char *model_path_str = env->GetStringUTFChars(modelPath, nullptr);
    const char *config_path_str = configPath ? env->GetStringUTFChars(configPath, nullptr) : nullptr;
    const char *espeak_data_path_str = env->GetStringUTFChars(espeakDataPath, nullptr);

    LOGI("Creating Piper synthesizer: model=%s, config=%s, espeak=%s",
         model_path_str, config_path_str ? config_path_str : "null", espeak_data_path_str);

    piper_synthesizer *synth = piper_create(model_path_str, config_path_str, espeak_data_path_str);

    env->ReleaseStringUTFChars(modelPath, model_path_str);
    if (config_path_str) {
        env->ReleaseStringUTFChars(configPath, config_path_str);
    }
    env->ReleaseStringUTFChars(espeakDataPath, espeak_data_path_str);

    if (!synth) {
        LOGE("Failed to create Piper synthesizer");
        return 0;
    }

    LOGI("Piper synthesizer created successfully");
    return reinterpret_cast<jlong>(synth);
}

JNIEXPORT void JNICALL
Java_com_piper_tts_PiperTTS_nativeFree(JNIEnv *env, jobject thiz, jlong handle) {
    piper_synthesizer *synth = reinterpret_cast<piper_synthesizer *>(handle);
    if (synth) {
        LOGI("Freeing Piper synthesizer");
        piper_free(synth);
    }
}

JNIEXPORT jshortArray JNICALL
Java_com_piper_tts_PiperTTS_nativeSynthesize(JNIEnv *env, jobject thiz, jlong handle, jstring text) {
    piper_synthesizer *synth = reinterpret_cast<piper_synthesizer *>(handle);
    if (!synth) {
        LOGE("Invalid synthesizer handle");
        return nullptr;
    }

    const char *text_str = env->GetStringUTFChars(text, nullptr);
    LOGI("Synthesizing text: %s", text_str);

    // Start synthesis with default options
    piper_synthesize_options options = piper_default_synthesize_options(synth);
    int result = piper_synthesize_start(synth, text_str, &options);
    env->ReleaseStringUTFChars(text, text_str);

    if (result != PIPER_OK) {
        LOGE("Failed to start synthesis: %d", result);
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
            LOGE("Synthesis error: %d", result);
            return nullptr;
        }

        // Append samples
        all_samples.insert(all_samples.end(), chunk.samples, chunk.samples + chunk.num_samples);

        if (chunk.is_last) {
            break;
        }
    }

    LOGI("Synthesized %zu samples", all_samples.size());

    // Convert float samples to 16-bit PCM
    jshortArray result_array = env->NewShortArray(all_samples.size());
    if (!result_array) {
        LOGE("Failed to allocate output array");
        return nullptr;
    }

    std::vector<jshort> pcm_samples(all_samples.size());
    for (size_t i = 0; i < all_samples.size(); i++) {
        // Clamp float sample (-1.0 to 1.0) to 16-bit range
        float sample = all_samples[i];
        if (sample > 1.0f) sample = 1.0f;
        if (sample < -1.0f) sample = -1.0f;
        pcm_samples[i] = static_cast<jshort>(sample * 32767.0f);
    }

    env->SetShortArrayRegion(result_array, 0, pcm_samples.size(), pcm_samples.data());
    return result_array;
}

JNIEXPORT jint JNICALL
Java_com_piper_tts_PiperTTS_nativeGetSampleRate(JNIEnv *env, jobject thiz, jlong handle) {
    piper_synthesizer *synth = reinterpret_cast<piper_synthesizer *>(handle);
    if (!synth) {
        LOGE("Invalid synthesizer handle");
        return 0;
    }

    return piper_get_sample_rate(synth);
}

} // extern "C"
