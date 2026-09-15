package com.kluivert.pinputkit

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import java.security.MessageDigest

/**
 * Kotlin side of pinput_kit. Called from pinput_kit.cpp (Dart → native) and
 * calls Dart back through [fireToDart]: one dispatcher pointer, one
 * generation stamp, re-checked before every delivery, always on the main
 * thread.
 */
object PinputKitBridge {
    private const val TAG = "PinputKit"

    // The framework's DNAppContext / DNViewRegistry are reached reflectively
    // so this module compiles standalone (the app always provides them).
    private val appContextClass: Class<*>? by lazy {
        try { Class.forName("com.dartnative.DNAppContext") } catch (_: Throwable) { null }
    }

    private fun appContext(): Context? = try {
        appContextClass?.getMethod("get")?.invoke(null) as? Context
    } catch (_: Throwable) { null }

    private fun currentActivity(): Activity? = try {
        appContextClass?.getMethod("activity")?.invoke(null) as? Activity
    } catch (_: Throwable) { null }

    private fun frameworkView(viewId: Long): View? = try {
        val cls = Class.forName("com.dartnative.DNViewRegistry")
        val instance = cls.getField("INSTANCE").get(null)
        cls.getMethod("view", java.lang.Long.TYPE).invoke(instance, viewId) as? View
    } catch (_: Throwable) { null }

    const val EVENT_MESSAGE = 1
    const val EVENT_TIMEOUT = 2
    const val EVENT_ERROR = 3

    const val MODE_RETRIEVER = 0
    const val MODE_USER_CONSENT = 1

    @Volatile private var dispatcherPtr: Long = 0L
    @Volatile private var dispatcherGen: Long = 0L
    private val main = Handler(Looper.getMainLooper())

    private var receiver: BroadcastReceiver? = null
    private var activeToken: Long = 0L
    private var activeMode: Int = MODE_RETRIEVER

    // ── Dispatcher slot ────────────────────────────────────────────────

    @JvmStatic
    fun setDispatcher(ptr: Long) {
        dispatcherPtr = ptr
        dispatcherGen = nativeIsolateGen() // capture the counter WITH the ptr
    }

    @JvmStatic external fun nativeIsolateGen(): Long
    @JvmStatic external fun nativeDeliver(ptr: Long, token: Long, type: Int, payload: String)

    private fun fireToDart(token: Long, type: Int, payload: String) {
        main.post {
            if (dispatcherGen != nativeIsolateGen()) return@post // restarted → drop
            val ptr = dispatcherPtr
            if (ptr == 0L) return@post
            nativeDeliver(ptr, token, type, payload)
        }
    }

    // ── User Consent prompt result (from PinputKitConsentActivity) ─────

    fun onConsentResult(resultCode: Int, data: Intent?) {
        val token = activeToken
        if (token == 0L) return
        if (resultCode == Activity.RESULT_OK && data != null) {
            val message = data.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE) ?: ""
            fireToDart(token, EVENT_MESSAGE, message)
        } else {
            fireToDart(token, EVENT_ERROR, "user consent denied")
        }
        smsStop(token)
    }

    // ── SMS listening ──────────────────────────────────────────────────

    /** Returns 0 when the listener started, else an error code. */
    @JvmStatic
    fun smsStart(token: Long, mode: Int): Int {
        val ctx = appContext() ?: return 1
        smsStop(activeToken)
        activeToken = token
        activeMode = mode

        val newReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                val extras = intent.extras ?: return
                @Suppress("DEPRECATION")
                val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status ?: return
                when (status.statusCode) {
                    CommonStatusCodes.SUCCESS -> {
                        if (activeMode == MODE_USER_CONSENT) {
                            @Suppress("DEPRECATION")
                            val consent = extras.getParcelable<Intent>(SmsRetriever.EXTRA_CONSENT_INTENT)
                            if (consent == null) {
                                fireToDart(token, EVENT_ERROR, "no consent intent")
                                smsStop(token)
                                return
                            }
                            try {
                                PinputKitConsentActivity.start(currentActivity() ?: context, consent)
                            } catch (e: Exception) {
                                fireToDart(token, EVENT_ERROR, "consent prompt failed: ${e.message}")
                                smsStop(token)
                            }
                        } else {
                            val message = extras.getString(SmsRetriever.EXTRA_SMS_MESSAGE) ?: ""
                            fireToDart(token, EVENT_MESSAGE, message)
                            smsStop(token)
                        }
                    }
                    CommonStatusCodes.TIMEOUT -> {
                        fireToDart(token, EVENT_TIMEOUT, "")
                        smsStop(token)
                    }
                }
            }
        }
        val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // The broadcast comes from Play services, not the system, so the
                // receiver must be exported and guarded by SEND_PERMISSION.
                ctx.registerReceiver(newReceiver, filter, SmsRetriever.SEND_PERMISSION, null,
                    Context.RECEIVER_EXPORTED)
            } else {
                ctx.registerReceiver(newReceiver, filter, SmsRetriever.SEND_PERMISSION, null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "registerReceiver failed: ${e.message}")
            return 2
        }
        receiver = newReceiver

        val client = SmsRetriever.getClient(ctx)
        val task = if (mode == MODE_USER_CONSENT) client.startSmsUserConsent(null)
                   else client.startSmsRetriever()
        task.addOnFailureListener { e ->
            Log.e(TAG, "SmsRetriever start failed: ${e.message}")
            fireToDart(token, EVENT_ERROR, e.message ?: "start failed")
            smsStop(token)
        }
        return 0
    }

    /** Stops the listener started with [token] (0 stops whichever is active). */
    @JvmStatic
    fun smsStop(token: Long) {
        if (token != 0L && token != activeToken) return
        val r = receiver ?: return
        receiver = null
        activeToken = 0L
        try {
            appContext()?.unregisterReceiver(r)
        } catch (_: Exception) {
        }
    }

    // ── App signature (SMS Retriever hash) ─────────────────────────────

    /** Comma-separated 11-character hashes, one per signing certificate. */
    @JvmStatic
    fun appSignature(): String {
        val ctx = appContext() ?: return ""
        val pkg = ctx.packageName
        val signatures: List<Signature> = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = ctx.packageManager.getPackageInfo(pkg, PackageManager.GET_SIGNING_CERTIFICATES)
                info.signingInfo?.apkContentsSigners?.toList() ?: emptyList()
            } else {
                @Suppress("DEPRECATION")
                ctx.packageManager.getPackageInfo(pkg, PackageManager.GET_SIGNATURES)
                    .signatures?.toList() ?: emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "signature lookup failed: ${e.message}")
            emptyList()
        }
        return signatures.mapNotNull { hash(pkg, it.toCharsString()) }.joinToString(",")
    }

    // Google's AppSignatureHelper: SHA-256 of "<package> <signature>",
    // first 9 bytes, base64 → first 11 characters.
    private fun hash(pkg: String, signature: String): String? = try {
        val digest = MessageDigest.getInstance("SHA-256")
        digest.update("$pkg $signature".toByteArray(Charsets.UTF_8))
        val bytes = digest.digest().copyOfRange(0, 9)
        Base64.encodeToString(bytes, Base64.NO_PADDING or Base64.NO_WRAP).substring(0, 11)
    } catch (e: Exception) {
        null
    }

    // ── One-time-code autofill hint ────────────────────────────────────

    @JvmStatic
    fun setOneTimeCodeHint(viewId: Long): Int {
        val view = frameworkView(viewId) ?: return 1
        val editText = findEditText(view) ?: return 2
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            editText.setAutofillHints("smsOTPCode") // View.AUTOFILL_HINT_SMS_OTP
            editText.importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_YES
        }
        return 0
    }

    // ── Soft keyboard ──────────────────────────────────────────────────

    /**
     * Shows the soft keyboard for the text field behind [viewId].
     *
     * Needed after the user presses the system back button: Android hides
     * the keyboard but the EditText keeps focus, so requesting focus again
     * does nothing. Asking the input method manager directly brings the
     * keyboard back. Runs on the main thread.
     *
     * Returns 0 on success, 1 when the view id is unknown, 2 when the view
     * holds no EditText.
     */
    @JvmStatic
    fun showKeyboard(viewId: Long): Int {
        val view = frameworkView(viewId) ?: return 1
        val editText = findEditText(view) ?: return 2
        val show = Runnable {
            if (!editText.hasFocus()) editText.requestFocus()
            val imm = editText.context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
        }
        if (Looper.myLooper() == Looper.getMainLooper()) show.run()
        else Handler(Looper.getMainLooper()).post(show)
        return 0
    }

    private fun findEditText(view: View): EditText? {
        if (view is EditText) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                findEditText(view.getChildAt(i))?.let { return it }
            }
        }
        return null
    }
}
