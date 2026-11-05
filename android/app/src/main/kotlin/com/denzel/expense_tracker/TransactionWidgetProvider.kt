package com.denzel.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray

@Suppress("DEPRECATION")
class TransactionWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateWidget(context, manager, it) }
    }
    override fun onDeleted(context: Context, ids: IntArray) {
        val editor = preferences(context).edit()
        ids.forEach { editor.remove("account_$it").remove("owner_$it") }
        editor.apply()
    }
    override fun onRestored(context: Context, oldIds: IntArray, newIds: IntArray) {
        val prefs = preferences(context)
        val editor = prefs.edit()
        oldIds.zip(newIds).forEach { (old, new) ->
            editor.putString("account_$new", prefs.getString("account_$old", null))
            editor.putString("owner_$new", prefs.getString("owner_$old", null))
            editor.remove("account_$old").remove("owner_$old")
        }
        editor.apply()
        onUpdate(context, AppWidgetManager.getInstance(context), newIds)
    }
    companion object {
        const val PREFS = "pocket_ledger_home_widgets"
        const val ACTION_QUICK_ENTRY = "com.denzel.expense_tracker.WIDGET_QUICK_ENTRY"
        fun preferences(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        fun accounts(context: Context): JSONArray = try { JSONArray(preferences(context).getString("accounts", "[]") ?: "[]") } catch (_: Exception) { JSONArray() }
        fun readableAccent(context: Context): Int {
            val prefs = preferences(context)
            val seed = prefs.getInt("accent", Color.rgb(59, 130, 246))
            val dark = prefs.getBoolean("dark", true)
            val weight = if (dark && Color.luminance(seed) < 0.3) 0.55 else if (!dark && Color.luminance(seed) > 0.15) -0.55 else 0.0
            fun channel(value: Int) = if (weight >= 0) (value + (255 - value) * weight).toInt() else (value * (1 + weight)).toInt()
            return Color.rgb(channel(Color.red(seed)), channel(Color.green(seed)), channel(Color.blue(seed)))
        }
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, TransactionWidgetProvider::class.java)).forEach { updateWidget(context, manager, it) }
        }
        fun updateWidget(context: Context, manager: AppWidgetManager, id: Int, resetSelection: Boolean = false) {
            val prefs = preferences(context)
            val dark = prefs.getBoolean("dark", true)
            val owner = prefs.getString("owner", null)
            val authorized = prefs.getBoolean("authorized", false) && owner != null && prefs.getString("owner_$id", null) == owner
            val views = RemoteViews(context.packageName, R.layout.transaction_home_widget)
            val foreground = if (dark) Color.WHITE else Color.rgb(20, 28, 45)
            views.setTextColor(R.id.widget_empty, foreground)
            views.setInt(R.id.widget_background, "setColorFilter", if (dark) Color.rgb(16, 24, 42) else Color.rgb(245, 247, 255))
            views.setTextViewText(R.id.widget_empty, if (!prefs.getBoolean("authorized", false)) "Open Pocket Ledger and sign in" else "Tap to set up your account carousel")
            val service = Intent(context, AccountWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse("pocketledger-widget://adapter/$id")
            }
            views.setRemoteAdapter(R.id.widget_accounts, service)
            views.setEmptyView(R.id.widget_accounts, R.id.widget_empty)
            val entry = Intent(context, MainActivity::class.java).apply {
                action = ACTION_QUICK_ENTRY
                data = Uri.parse("pocketledger-widget://entries/$id")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            // Collections require a mutable, explicit template so each card can
            // supply its account and action. Flutter still verifies auth/account.
            val template = PendingIntent.getActivity(context, id, entry, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
            views.setPendingIntentTemplate(R.id.widget_accounts, template)
            val setup = if (prefs.getBoolean("authorized", false)) Intent(context, TransactionWidgetConfigureActivity::class.java).apply { putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id) } else Intent(context, MainActivity::class.java)
            setup.data = Uri.parse("pocketledger-widget://setup/$id")
            views.setOnClickPendingIntent(R.id.widget_empty, PendingIntent.getActivity(context, id, setup, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            if (resetSelection && authorized) {
                val all = accounts(context)
                val selected = prefs.getString("account_$id", null)
                val index = (0 until all.length()).firstOrNull { all.optJSONObject(it)?.optString("id") == selected } ?: 0
                views.setScrollPosition(R.id.widget_accounts, index)
            }
            manager.updateAppWidget(id, views)
            manager.notifyAppWidgetViewDataChanged(id, R.id.widget_accounts)
        }
    }
}
