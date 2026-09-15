package com.kluivert.pinputkit

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * Invisible proxy that shows the SMS User Consent prompt and hands its result
 * to [PinputKitBridge]. The DartNative embedding exposes no activity-result
 * hook to plugins, so the plugin owns the Activity that receives it.
 */
class PinputKitConsentActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) return
        @Suppress("DEPRECATION")
        val consent = intent.getParcelableExtra<Intent>(EXTRA_CONSENT)
        if (consent == null) {
            PinputKitBridge.onConsentResult(RESULT_CANCELED, null)
            finish()
            return
        }
        try {
            startActivityForResult(consent, REQUEST_CONSENT)
        } catch (e: Exception) {
            PinputKitBridge.onConsentResult(RESULT_CANCELED, null)
            finish()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CONSENT) {
            PinputKitBridge.onConsentResult(resultCode, data)
        }
        finish()
    }

    companion object {
        private const val EXTRA_CONSENT = "com.kluivert.pinputkit.CONSENT"
        private const val REQUEST_CONSENT = 0x5150

        fun start(context: Context, consent: Intent) {
            val launcher = Intent(context, PinputKitConsentActivity::class.java)
                .putExtra(EXTRA_CONSENT, consent)
            if (context !is Activity) launcher.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launcher)
        }
    }
}
