package com.denzel.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import kotlin.math.min

@Suppress("DEPRECATION")
class TransactionWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateWidget(context, manager, it) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        updateWidget(context, manager, id)
    }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_NEXT && intent.action != ACTION_PREVIOUS) return
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val manager = AppWidgetManager.getInstance(context)
        if (id !in manager.getAppWidgetIds(ComponentName(context, TransactionWidgetProvider::class.java))) return
        val prefs = preferences(context)
        val owner = prefs.getString("owner", null)
        if (!prefs.getBoolean("authorized", false) || owner == null || prefs.getString("owner_$id", null) != owner) return
        val all = accounts(context)
        if (all.length() == 0) return
        val selected = prefs.getString("account_$id", null)
        val current = (0 until all.length()).firstOrNull { all.optJSONObject(it)?.optString("id") == selected } ?: 0
        val step = if (intent.action == ACTION_NEXT) 1 else -1
        val next = (current + step + all.length()) % all.length()
        prefs.edit().putString("account_$id", all.getJSONObject(next).getString("id")).apply()
        updateWidget(context, manager, id)
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
        private const val ACTION_NEXT = "com.denzel.expense_tracker.WIDGET_NEXT"
        private const val ACTION_PREVIOUS = "com.denzel.expense_tracker.WIDGET_PREVIOUS"
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
        fun updateWidget(context: Context, manager: AppWidgetManager, id: Int) {
            val options = manager.getAppWidgetOptions(id)
            // Exact layouts let Android select the right scale when the launcher
            // resizes or rotates the widget, without a fixed-height viewport.
            val sizes = if (Build.VERSION.SDK_INT >= 31) options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)?.filter { it.width > 0f && it.height > 0f } else null
            val views = if (Build.VERSION.SDK_INT >= 31 && !sizes.isNullOrEmpty()) {
                RemoteViews(sizes.distinct().take(16).associateWith { size -> render(context, id, size.width, size.height) })
            } else {
                val portrait = context.resources.configuration.orientation != Configuration.ORIENTATION_LANDSCAPE
                val width = options.getInt(if (portrait) AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 300)
                val height = options.getInt(if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 56)
                render(context, id, width.toFloat(), height.toFloat())
            }
            manager.updateAppWidget(id, views)
        }
        private fun render(context: Context, id: Int, width: Float, height: Float): RemoteViews {
            val prefs = preferences(context)
            val dark = prefs.getBoolean("dark", true)
            val owner = prefs.getString("owner", null)
            val authorized = prefs.getBoolean("authorized", false) && owner != null && prefs.getString("owner_$id", null) == owner
            val all = if (authorized) accounts(context) else JSONArray()
            val selected = prefs.getString("account_$id", null)
            val index = (0 until all.length()).firstOrNull { all.optJSONObject(it)?.optString("id") == selected } ?: 0
            val account = all.optJSONObject(index)
            val views = RemoteViews(context.packageName, R.layout.transaction_home_widget)
            val foreground = if (dark) Color.WHITE else Color.rgb(20, 28, 45)
            val accent = readableAccent(context)
            views.setInt(R.id.widget_background, "setColorFilter", if (dark) Color.rgb(16, 24, 42) else Color.rgb(245, 247, 255))
            views.setViewVisibility(R.id.widget_row, if (account == null) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, if (account == null) View.VISIBLE else View.GONE)
            views.setTextColor(R.id.widget_empty, foreground)
            views.setTextViewText(R.id.widget_empty, if (!prefs.getBoolean("authorized", false)) "Open Pocket Ledger and sign in" else "Tap to choose an account")
            val setup = if (prefs.getBoolean("authorized", false)) Intent(context, TransactionWidgetConfigureActivity::class.java).apply { putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id) } else Intent(context, MainActivity::class.java)
            setup.data = Uri.parse("pocketledger-widget://setup/$id")
            views.setOnClickPendingIntent(R.id.widget_empty, PendingIntent.getActivity(context, id, setup, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            if (account == null) return views
            val scale = min(1f + (height - 56f).coerceAtLeast(0f) / 200f, width / 250f).coerceIn(1f, 1.5f)
            fun px(dp: Float) = (dp * context.resources.displayMetrics.density).toInt()
            views.setTextViewText(R.id.card_name, account.optString("name"))
            views.setTextViewText(R.id.card_balance, account.optString("balance", "€0.00"))
            views.setTextColor(R.id.card_name, foreground)
            views.setTextColor(R.id.card_balance, foreground)
            views.setInt(R.id.card_balance, "setMaxWidth", px((width * 0.35f).coerceIn(80f, 180f)))
            views.setTextColor(R.id.card_transaction, accent)
            views.setTextViewTextSize(R.id.card_name, android.util.TypedValue.COMPLEX_UNIT_SP, 13f * scale)
            views.setTextViewTextSize(R.id.card_balance, android.util.TypedValue.COMPLEX_UNIT_SP, 17f * scale)
            views.setTextViewTextSize(R.id.card_transaction, android.util.TypedValue.COMPLEX_UNIT_SP, 26f * scale)
            views.setInt(R.id.card_transaction, "setMinWidth", px(48f * scale))
            views.setInt(R.id.card_transaction, "setMinHeight", px(48f * scale))
            val icon = when (account.optString("type")) {
                "Savings" -> R.drawable.widget_icon_savings
                "Joint" -> R.drawable.widget_icon_joint
                "Loan" -> R.drawable.widget_icon_loan
                else -> R.drawable.widget_icon_current
            }
            val drawable = context.getDrawable(icon)!!.mutate()
            drawable.setTint(accent)
            val iconSize = px(24f * scale).coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(iconSize, iconSize, Bitmap.Config.ARGB_8888)
            bitmap.density = context.resources.displayMetrics.densityDpi
            drawable.setBounds(0, 0, iconSize, iconSize)
            drawable.draw(Canvas(bitmap))
            views.setImageViewBitmap(R.id.card_icon, bitmap)
            views.setContentDescription(R.id.card_icon, account.optString("type"))
            views.setContentDescription(R.id.card_transaction, "Add transaction to ${account.optString("name")}")
            views.setContentDescription(R.id.card_name, "${account.optString("name")}, account ${index + 1} of ${all.length()}")
            for ((viewId, actionName) in listOf(R.id.widget_previous to ACTION_PREVIOUS, R.id.widget_next to ACTION_NEXT)) {
                views.setViewVisibility(viewId, if (all.length() > 1) View.VISIBLE else View.GONE)
                views.setTextColor(viewId, accent)
                val navigate = Intent(context, TransactionWidgetProvider::class.java).apply {
                    action = actionName
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    data = Uri.parse("pocketledger-widget://navigate/$id/$actionName")
                }
                views.setOnClickPendingIntent(viewId, PendingIntent.getBroadcast(context, id, navigate, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            val entry = Intent(context, MainActivity::class.java).apply {
                action = ACTION_QUICK_ENTRY
                // Different accounts get different PendingIntents; an old view
                // can never accidentally transact against the newly selected one.
                data = Uri.parse("pocketledger-widget://entries/$id/${account.optString("id")}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("accountId", account.getString("id"))
                putExtra("kind", "choose")
            }
            views.setOnClickPendingIntent(R.id.card_transaction, PendingIntent.getActivity(context, id, entry, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            return views
        }
    }
}
