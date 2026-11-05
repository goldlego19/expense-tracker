package com.denzel.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.DateFormat
import java.util.Date

class AccountWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = AccountFactory(applicationContext, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID))
}
private class AccountFactory(private val context: Context, private val widgetId: Int) : RemoteViewsService.RemoteViewsFactory {
    private var items = JSONArray()
    override fun onCreate() { load() }
    override fun onDataSetChanged() { load() }
    private fun load() {
        val prefs = TransactionWidgetProvider.preferences(context)
        val owner = prefs.getString("owner", null)
        items = if (prefs.getBoolean("authorized", false) && owner != null && prefs.getString("owner_$widgetId", null) == owner) TransactionWidgetProvider.accounts(context) else JSONArray()
    }
    override fun onDestroy() { items = JSONArray() }
    override fun getCount(): Int = items.length()
    override fun getViewTypeCount(): Int = 1
    override fun getLoadingView(): RemoteViews? = null
    override fun hasStableIds(): Boolean = true
    override fun getItemId(position: Int): Long = items.optJSONObject(position)?.optString("id")?.fold(1125899906842597L) { hash, char -> hash * 31 + char.code } ?: position.toLong()
    override fun getViewAt(position: Int): RemoteViews {
        val account = items.optJSONObject(position) ?: return RemoteViews(context.packageName, R.layout.transaction_widget_account)
        val prefs = TransactionWidgetProvider.preferences(context)
        val dark = prefs.getBoolean("dark", true)
        val foreground = if (dark) Color.WHITE else Color.rgb(20, 28, 45)
        val secondary = if (dark) Color.rgb(183, 193, 213) else Color.rgb(75, 85, 105)
        val views = RemoteViews(context.packageName, R.layout.transaction_widget_account)
        views.setTextViewText(R.id.card_name, account.optString("name"))
        views.setTextViewText(R.id.card_balance, account.optString("balance", "€0.00"))
        val updated = prefs.getLong("syncedAt", 0L)
        val time = if (updated == 0L) "Open app to sync" else "Synced ${DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(updated))}"
        views.setTextViewText(R.id.card_type, "${account.optString("type")} · ${position + 1}/${items.length()} · $time")
        views.setTextColor(R.id.card_name, foreground)
        views.setTextColor(R.id.card_balance, foreground)
        views.setTextColor(R.id.card_type, secondary)
        views.setTextColor(R.id.card_expense, TransactionWidgetProvider.readableAccent(context))
        views.setTextColor(R.id.card_income, TransactionWidgetProvider.readableAccent(context))
        val icon = when (account.optString("type")) {
            "Savings" -> R.drawable.widget_icon_savings
            "Joint" -> R.drawable.widget_icon_joint
            "Loan" -> R.drawable.widget_icon_loan
            else -> R.drawable.widget_icon_current
        }
        views.setImageViewResource(R.id.card_icon, icon)
        views.setInt(R.id.card_icon, "setColorFilter", TransactionWidgetProvider.readableAccent(context))
        fun action(kind: String) = Intent().putExtra("accountId", account.getString("id")).putExtra("kind", kind)
        views.setOnClickFillInIntent(R.id.card_expense, action("expense"))
        views.setOnClickFillInIntent(R.id.card_income, action("income"))
        views.setOnClickFillInIntent(R.id.card_name, action("expense"))
        return views
    }
}
