package com.denzel.expense_tracker

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null
    private var pendingLaunch: Map<String, String>? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureWidgetLaunch(intent)
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocket_ledger/home_widget").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeLaunch" -> {
                        val launch = pendingLaunch
                        clearLaunch()
                        result.success(launch)
                    }
                    "ackLaunch" -> {
                        if (call.argument<String>("requestId") == pendingLaunch?.get("requestId")) clearLaunch()
                        result.success(null)
                    }
                    "syncAccounts" -> {
                        val authorized = call.argument<Boolean>("authorized") ?: false
                        val prefs = TransactionWidgetProvider.preferences(this)
                        prefs.edit().putBoolean("authorized", authorized)
                            .putString("owner", if (authorized) call.argument<String>("owner") else null)
                            .putString("accounts", if (authorized) call.argument<String>("accounts") ?: "[]" else "[]")
                            .putLong("syncedAt", System.currentTimeMillis()).apply()
                        TransactionWidgetProvider.refreshAll(this)
                        result.success(null)
                    }
                    "syncAppearance" -> {
                        val accent = call.argument<Number>("accent")?.toInt() ?: 0xff3b82f6.toInt()
                        val dark = call.argument<Boolean>("dark") ?: true
                        TransactionWidgetProvider.preferences(this).edit().putInt("accent", accent).putBoolean("dark", dark).apply()
                        TransactionWidgetProvider.refreshAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetLaunch(intent)
        pendingLaunch?.let { widgetChannel?.invokeMethod("widgetLaunch", it) }
    }
    private fun captureWidgetLaunch(intent: Intent?) {
        if (intent?.action != TransactionWidgetProvider.ACTION_QUICK_ENTRY) return
        val account = intent.getStringExtra("accountId") ?: return
        val kind = intent.getStringExtra("kind") ?: return
        if (account.isBlank() || account.contains('/') || kind !in listOf("expense", "income", "choose")) return
        pendingLaunch = mapOf("requestId" to UUID.randomUUID().toString(), "accountId" to account, "kind" to kind)
    }
    private fun clearLaunch() {
        pendingLaunch = null
        if (intent?.action == TransactionWidgetProvider.ACTION_QUICK_ENTRY) {
            intent.action = Intent.ACTION_MAIN
            intent.removeExtra("accountId")
            intent.removeExtra("kind")
        }
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        widgetChannel?.setMethodCallHandler(null)
        widgetChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
