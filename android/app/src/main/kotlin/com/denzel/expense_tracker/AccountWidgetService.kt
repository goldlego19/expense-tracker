package com.denzel.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

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
        val views = RemoteViews(context.packageName, R.layout.transaction_widget_account)
        views.setTextViewText(R.id.card_name, account.optString("name"))
        views.setTextViewText(R.id.card_balance, account.optString("balance", "€0.00"))
        views.setTextColor(R.id.card_name, foreground)
        views.setTextColor(R.id.card_balance, foreground)
        views.setTextColor(R.id.card_transaction, TransactionWidgetProvider.readableAccent(context))
        val icon = when (account.optString("type")) {
            "Savings" -> R.drawable.widget_icon_savings
            "Joint" -> R.drawable.widget_icon_joint
            "Loan" -> R.drawable.widget_icon_loan
            else -> R.drawable.widget_icon_current
        }
        views.setImageViewResource(R.id.card_icon, icon)
        views.setInt(R.id.card_icon, "setColorFilter", TransactionWidgetProvider.readableAccent(context))
        views.setContentDescription(R.id.card_transaction, "Add transaction to ${account.optString("name")}")
        views.setOnClickFillInIntent(R.id.card_transaction, Intent()
            .putExtra("accountId", account.getString("id"))
            .putExtra("kind", "choose"))
        return views
    }
}
