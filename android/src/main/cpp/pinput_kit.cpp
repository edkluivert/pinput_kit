// pinput_kit — Android FFI entry points.
//
// Dart calls the exported PinputKit* functions below (DynamicLibrary.open
// "libpinput_kit.so"); they forward to the Kotlin object
// com.kluivert.pinputkit.PinputKitBridge over JNI. Kotlin calls Dart back
// (an SMS arriving) through nativeDeliver, guarded by the framework's
// restart counter DN_IsolateGen().
//
// JNI_OnLoad runs when PinputKitPlugin.onAttachedToEngine calls
// System.loadLibrary("pinput_kit"), which is why the plugin must be declared
// with pluginClass (not ffiPlugin) on Android.

#include <android/log.h>
#include <dlfcn.h>
#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define EXPORT extern "C" __attribute__((visibility("default")))
#define LOG_TAG "PinputKit"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static JavaVM* g_jvm = nullptr;
static jclass g_bridge = nullptr;
static jmethodID g_setDispatcher = nullptr;
static jmethodID g_smsStart = nullptr;
static jmethodID g_smsStop = nullptr;
static jmethodID g_appSignature = nullptr;
static jmethodID g_setOneTimeCode = nullptr;
static jmethodID g_showKeyboard = nullptr;

static JNIEnv* envForThisThread() {
  if (g_jvm == nullptr) return nullptr;
  JNIEnv* env = nullptr;
  jint rc = g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
  if (rc == JNI_EDETACHED) {
    if (g_jvm->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
  } else if (rc != JNI_OK) {
    return nullptr;
  }
  return env;
}

static void clearException(JNIEnv* env) {
  if (env->ExceptionCheck()) {
    env->ExceptionDescribe();
    env->ExceptionClear();
  }
}

// ── Kotlin → Dart (registered natives) ──────────────────────────────────

// Reads the framework's restart counter from the core library.
static jlong nativeIsolateGen(JNIEnv*, jclass) {
  using GenFn = uint64_t (*)();
  static GenFn fn = reinterpret_cast<GenFn>(dlsym(RTLD_DEFAULT, "DN_IsolateGen"));
  return fn ? static_cast<jlong>(fn()) : 0;
}

// Invokes the Dart dispatcher pointer. Dart copies the string during the
// call, so the UTF chars can be released right after.
static void nativeDeliver(JNIEnv* env, jclass, jlong ptr, jlong token,
                          jint type, jstring payload) {
  using Dispatch = void (*)(int64_t, int32_t, const char*);
  if (ptr == 0) return;
  const char* cStr = payload ? env->GetStringUTFChars(payload, nullptr) : nullptr;
  reinterpret_cast<Dispatch>(ptr)(token, type, cStr ? cStr : "");
  if (payload && cStr) env->ReleaseStringUTFChars(payload, cStr);
}

extern "C" JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void*) {
  g_jvm = vm;
  JNIEnv* env = nullptr;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    return JNI_ERR;
  }
  jclass local = env->FindClass("com/kluivert/pinputkit/PinputKitBridge");
  if (local == nullptr) {
    LOGE("PinputKitBridge class not found");
    clearException(env);
    return JNI_ERR;
  }
  g_bridge = static_cast<jclass>(env->NewGlobalRef(local));
  env->DeleteLocalRef(local);

  g_setDispatcher = env->GetStaticMethodID(g_bridge, "setDispatcher", "(J)V");
  g_smsStart = env->GetStaticMethodID(g_bridge, "smsStart", "(JI)I");
  g_smsStop = env->GetStaticMethodID(g_bridge, "smsStop", "(J)V");
  g_appSignature =
      env->GetStaticMethodID(g_bridge, "appSignature", "()Ljava/lang/String;");
  g_setOneTimeCode =
      env->GetStaticMethodID(g_bridge, "setOneTimeCodeHint", "(J)I");
  g_showKeyboard = env->GetStaticMethodID(g_bridge, "showKeyboard", "(J)I");
  clearException(env);

  static const JNINativeMethod methods[] = {
      {"nativeIsolateGen", "()J", reinterpret_cast<void*>(nativeIsolateGen)},
      {"nativeDeliver", "(JJILjava/lang/String;)V",
       reinterpret_cast<void*>(nativeDeliver)},
  };
  if (env->RegisterNatives(g_bridge, methods, 2) != JNI_OK) {
    LOGE("RegisterNatives failed");
    clearException(env);
    return JNI_ERR;
  }
  return JNI_VERSION_1_6;
}

// ── Dart → Kotlin (exported for dart:ffi) ───────────────────────────────

EXPORT void PinputKitSetDispatcher(int64_t ptr) {
  JNIEnv* env = envForThisThread();
  if (env == nullptr || g_setDispatcher == nullptr) return;
  env->CallStaticVoidMethod(g_bridge, g_setDispatcher, static_cast<jlong>(ptr));
  clearException(env);
}

EXPORT int32_t PinputKitSmsStart(int64_t token, int32_t mode) {
  JNIEnv* env = envForThisThread();
  if (env == nullptr || g_smsStart == nullptr) return -2;
  jint rc = env->CallStaticIntMethod(g_bridge, g_smsStart,
                                     static_cast<jlong>(token),
                                     static_cast<jint>(mode));
  if (env->ExceptionCheck()) {
    clearException(env);
    return -3;
  }
  return rc;
}

EXPORT void PinputKitSmsStop(int64_t token) {
  JNIEnv* env = envForThisThread();
  if (env == nullptr || g_smsStop == nullptr) return;
  env->CallStaticVoidMethod(g_bridge, g_smsStop, static_cast<jlong>(token));
  clearException(env);
}

// Cached for the app lifetime — Dart copies it with toDartString().
EXPORT const char* PinputKitAppSignature() {
  static char* cached = nullptr;
  if (cached != nullptr) return cached;
  JNIEnv* env = envForThisThread();
  if (env == nullptr || g_appSignature == nullptr) return "";
  jstring s = static_cast<jstring>(
      env->CallStaticObjectMethod(g_bridge, g_appSignature));
  if (env->ExceptionCheck() || s == nullptr) {
    clearException(env);
    return "";
  }
  const char* c = env->GetStringUTFChars(s, nullptr);
  cached = strdup(c ? c : "");
  if (c) env->ReleaseStringUTFChars(s, c);
  env->DeleteLocalRef(s);
  return cached;
}

EXPORT int32_t PinputKitTextFieldSetOneTimeCode(int64_t viewId) {
  JNIEnv* env = envForThisThread();
  if (env == nullptr || g_setOneTimeCode == nullptr) return -2;
  jint rc = env->CallStaticIntMethod(g_bridge, g_setOneTimeCode,
                                     static_cast<jlong>(viewId));
  if (env->ExceptionCheck()) {
    clearException(env);
    return -3;
  }
  return rc;
}

EXPORT int32_t PinputKitTextFieldShowKeyboard(int64_t viewId) {
  JNIEnv* env = envForThisThread();
  if (env == nullptr || g_showKeyboard == nullptr) return -2;
  jint rc = env->CallStaticIntMethod(g_bridge, g_showKeyboard,
                                     static_cast<jlong>(viewId));
  if (env->ExceptionCheck()) {
    clearException(env);
    return -3;
  }
  return rc;
}
