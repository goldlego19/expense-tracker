package com.denzel.expense_tracker

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView

class TransactionWidgetConfigureActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) finish()
    }
    override fun onResume() {
        super.onResume()
        if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) render()
    }
    private fun render() {
        val prefs = TransactionWidgetProvider.preferences(this)
        val dark = prefs.getBoolean("dark", true)
        val textColor = if (dark) Color.WHITE else Color.rgb(20, 28, 45)
        val accent = prefs.getInt("accent", Color.rgb(59, 130, 246))
        val padding = (24 * resources.displayMetrics.density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
            setBackgroundColor(if (dark) Color.rgb(12, 18, 32) else Color.rgb(245, 247, 255))
        }
        fun label(text: String, size: Float) = TextView(this).apply { this.text = text; textSize = size; setTextColor(textColor); setPadding(0, padding / 2, 0, padding / 2) }
        root.addView(label("Choose the first account", 24f))
        root.addView(label("Use the arrows to switch between complete accounts. Resize the widget to grow the row. Choose which account to show first.", 15f))
        val accounts = TransactionWidgetProvider.accounts(this)
        val authorized = prefs.getBoolean("authorized", false)
        if (!authorized || accounts.length() == 0) {
            root.addView(label("Open Pocket Ledger, sign in and add an active account. Then return here to choose it.", 16f))
            root.addView(Button(this).apply {
                text = "Open Pocket Ledger"
                setTextColor(accent)
                setOnClickListener { startActivity(Intent(this@TransactionWidgetConfigureActivity, MainActivity::class.java)) }
            })
        } else {
            val names = (0 until accounts.length()).map { accounts.getJSONObject(it).getString("name") }
            val list = ListView(this)
            list.adapter = object : ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, names) {
                override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                    return (super.getView(position, convertView, parent) as TextView).apply { setTextColor(textColor) }
                }
            }
            list.setOnItemClickListener { _, _, position, _ ->
                prefs.edit().putString("account_$widgetId", accounts.getJSONObject(position).getString("id"))
                    .putString("owner_$widgetId", prefs.getString("owner", null)).apply()
                TransactionWidgetProvider.updateWidget(this, AppWidgetManager.getInstance(this), widgetId)
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                finish()
            }
            root.addView(list, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        }
        setContentView(root)
    }
}
