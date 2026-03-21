package com.mcdetail.moneydetail

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.widget.RemoteViews
import java.util.Locale

class ExpenseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val TODAY_KEY = "flutter.widget_today_total"
        private const val MONTH_KEY = "flutter.widget_month_total"

        fun requestUpdate(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetComponent = ComponentName(context, ExpenseWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
            if (appWidgetIds.isNotEmpty()) {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_today_value)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_month_value)
                appWidgetIds.forEach { updateAppWidget(context, appWidgetManager, it) }
            }
        }

        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val today = prefs.getFloat(TODAY_KEY, 0f).toDouble()
            val month = prefs.getFloat(MONTH_KEY, 0f).toDouble()

            val views = RemoteViews(context.packageName, R.layout.expense_widget)
            views.setTextViewText(R.id.widget_today_value, formatAmount(today))
            views.setTextViewText(R.id.widget_month_value, formatAmount(month))

            val isDark = isNightMode(context)
            val titleColor = if (isDark) Color.parseColor("#EAF6FF") else Color.parseColor("#0B2533")
            val labelColor = if (isDark) Color.parseColor("#B7D8E7") else Color.parseColor("#4A6572")
            val valueColor = if (isDark) Color.parseColor("#FFFFFF") else Color.parseColor("#0B2533")

            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_bg_dark else R.drawable.widget_bg_light
            )
            views.setInt(
                R.id.widget_add_button,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_button_dark else R.drawable.widget_button_light
            )
            views.setTextColor(R.id.widget_title, titleColor)
            views.setTextColor(R.id.widget_today_label, labelColor)
            views.setTextColor(R.id.widget_month_label, labelColor)
            views.setTextColor(R.id.widget_today_value, valueColor)
            views.setTextColor(R.id.widget_month_value, valueColor)
            views.setTextColor(
                R.id.widget_add_button,
                if (isDark) Color.parseColor("#04212A") else Color.WHITE
            )

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.mcdetail.moneydetail.OPEN_ENTRY"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val launchPendingIntent = PendingIntent.getActivity(
                context,
                1001,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val quickEntryIntent = Intent(context, WidgetQuickEntryActivity::class.java).apply {
                action = "com.mcdetail.moneydetail.WIDGET_QUICK_ENTRY"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val quickEntryPendingIntent = PendingIntent.getActivity(
                context,
                1002,
                quickEntryIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_add_button, quickEntryPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_root, launchPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun formatAmount(value: Double): String {
            return String.format(Locale.US, "¥%.2f", value)
        }

        private fun isNightMode(context: Context): Boolean {
            val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            return mode == Configuration.UI_MODE_NIGHT_YES
        }
    }
}
