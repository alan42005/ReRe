package com.example.reminder_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PriorityWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.priority_widget_layout).apply {
                val date = widgetData.getString("widget_date", "Today")
                val p1 = widgetData.getString("widget_p1", "No top priorities set")
                val p2 = widgetData.getString("widget_p2", "")
                val p3 = widgetData.getString("widget_p3", "")

                setTextViewText(R.id.widget_date, date)
                setTextViewText(R.id.widget_p1, p1)

                if (!p2.isNullOrEmpty()) {
                    setViewVisibility(R.id.widget_p2, View.VISIBLE)
                    setTextViewText(R.id.widget_p2, p2)
                } else {
                    setViewVisibility(R.id.widget_p2, View.GONE)
                }

                if (!p3.isNullOrEmpty()) {
                    setViewVisibility(R.id.widget_p3, View.VISIBLE)
                    setTextViewText(R.id.widget_p3, p3)
                } else {
                    setViewVisibility(R.id.widget_p3, View.GONE)
                }

                // Click on Focus Button launches app with Focus URI
                val focusIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rere://focus")
                )
                setOnClickPendingIntent(R.id.widget_focus_button, focusIntent)

                // Click on root opens planner
                val openAppIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rere://planner")
                )
                setOnClickPendingIntent(R.id.widget_root, openAppIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
