package com.example.liflow

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar

/**
 * Android XML widget provider backed by home_widget SharedPreferences.
 *
 * Data flow:
 * - Flutter writes a compact snapshot JSON into SharedPreferences via HomeWidget.saveWidgetData(...)
 * - This provider reads it and renders up to 8 pending tasks
 * - Clicking a task triggers a background Dart callback (interactive widget)
 */
class TaskWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences
  ) {
    var nextRefreshAt: Long? = null

    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.task_widget)
      try {
        val dayTasksJson = widgetData.getString(KEY_DAY_TASKS_JSON, "[]") ?: "[]"
        val tasks = parseTasks(dayTasksJson)
        val picked = pickCurrentTask(tasks)

        if (picked == null) {
          views.setViewVisibility(R.id.empty_state, View.VISIBLE)
          views.setViewVisibility(R.id.content, View.GONE)
        } else {
          views.setViewVisibility(R.id.empty_state, View.GONE)
          views.setViewVisibility(R.id.content, View.VISIBLE)

          views.setTextViewText(R.id.time_status, picked.timeStatus)
          views.setTextViewText(R.id.task_title, picked.title)
          views.setTextViewText(R.id.time_window, picked.timeWindow)

          // Interactive: mark as done (handled in Dart background callback)
          val uri = Uri.parse(
            "liflow://widget/markDone?weekId=${picked.weekId}&dayId=${picked.dayId}&activityId=${picked.activityId}"
          )
          val pendingIntent = HomeWidgetBackgroundIntent.getBroadcast(context, uri)
          views.setOnClickPendingIntent(R.id.check_circle, pendingIntent)

          // Schedule refresh at the next boundary.
          val refreshAt = picked.nextRefreshAt
          if (nextRefreshAt == null || refreshAt < nextRefreshAt!!) {
            nextRefreshAt = refreshAt
          }
        }
      } catch (_: Exception) {
        // If anything goes wrong (bad JSON, RemoteViews issue, etc), keep the widget loadable.
        views.setViewVisibility(R.id.empty_state, View.VISIBLE)
        views.setViewVisibility(R.id.content, View.GONE)
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }

    // Ensure the widget flips to the next task exactly on time.
    nextRefreshAt?.let { scheduleRefresh(context, appWidgetIds, it) }
  }

  private fun parseTasks(json: String): JSONArray {
    return try {
      JSONArray(json)
    } catch (e: Exception) {
      JSONArray()
    }
  }

  private data class Picked(
    val activityId: String,
    val weekId: String,
    val dayId: String,
    val time: String,
    val title: String,
    val timeStatus: String,
    val timeWindow: String,
    val nextRefreshAt: Long,
  )

  private fun parseMinutes(hhmm: String): Int? {
    val parts = hhmm.split(":")
    if (parts.size != 2) return null
    val h = parts[0].toIntOrNull() ?: return null
    val m = parts[1].toIntOrNull() ?: return null
    if (h !in 0..23) return null
    if (m !in 0..59) return null
    return h * 60 + m
  }

  private fun formatMinutes(minutes: Int): String {
    if (minutes < 60) return "$minutes min"

    val hours = minutes / 60
    val remaining = minutes % 60
    if (remaining == 0) return "${hours}h"
    return "${hours}h ${remaining}min"
  }

  private fun formatHHmm(minutes: Int): String {
    val h = (minutes / 60).toString().padStart(2, '0')
    val m = (minutes % 60).toString().padStart(2, '0')
    return "$h:$m"
  }

  private fun timeStatus(startMinutes: Int, nowMinutes: Int): String {
    val delta = startMinutes - nowMinutes
    return when {
      delta > 0 -> "em ${formatMinutes(delta)}"
      delta >= -5 -> "agora"
      else -> "em andamento"
    }
  }

  private fun timeWindow(time: String, nextMinutes: Int?): String {
    return if (nextMinutes == null) {
      "$time • fecha esse passo com calma"
    } else {
      "$time - ${formatHHmm(nextMinutes)} • um passo de cada vez"
    }
  }

  private fun nextMinuteAt(): Long {
    val c = Calendar.getInstance()
    c.set(Calendar.SECOND, 0)
    c.set(Calendar.MILLISECOND, 0)
    c.add(Calendar.MINUTE, 1)
    return c.timeInMillis
  }

  // Same rule as iOS widget:
  // - Between t[i] and t[i+1] => show t[i]
  // - Before first => show first
  // - After last => show last (refresh next day 00:01)
  private fun pickCurrentTask(tasks: JSONArray): Picked? {
    if (tasks.length() == 0) return null

    val parsed = mutableListOf<Pair<JSONObjectWrapper, Int>>()
    for (i in 0 until tasks.length()) {
      val obj = tasks.optJSONObject(i) ?: continue
      val time = obj.optString("time", "")
      val title = obj.optString("title", "")
      if (time.isEmpty() || title.isEmpty()) continue
      val minutes = parseMinutes(time) ?: continue
      parsed.add(JSONObjectWrapper(obj) to minutes)
    }

    if (parsed.isEmpty()) return null
    parsed.sortBy { it.second }

    val cal = Calendar.getInstance()
    val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

    fun todayAt(minutes: Int): Long {
      val c = Calendar.getInstance()
      c.set(Calendar.SECOND, 0)
      c.set(Calendar.MILLISECOND, 0)
      c.set(Calendar.HOUR_OF_DAY, minutes / 60)
      c.set(Calendar.MINUTE, minutes % 60)
      return c.timeInMillis
    }

    // Before first
    if (nowMinutes < parsed[0].second) {
      val o = parsed[0].first
      val start = parsed[0].second
      val nextStart = parsed.getOrNull(1)?.second
      val refreshAt = minOf(todayAt(start), nextMinuteAt())
      return Picked(
        activityId = o.activityId,
        weekId = o.weekId,
        dayId = o.dayId,
        time = o.time,
        title = o.title,
        timeStatus = timeStatus(start, nowMinutes),
        timeWindow = timeWindow(o.time, nextStart),
        nextRefreshAt = refreshAt,
      )
    }

    // Between
    for (idx in 0 until parsed.size) {
      val current = parsed[idx]
      val nextIdx = idx + 1
      if (nextIdx < parsed.size) {
        val next = parsed[nextIdx]
        if (nowMinutes >= current.second && nowMinutes < next.second) {
          val o = current.first
          val start = current.second
          val nextStart = next.second
          return Picked(
            activityId = o.activityId,
            weekId = o.weekId,
            dayId = o.dayId,
            time = o.time,
            title = o.title,
            timeStatus = timeStatus(start, nowMinutes),
            timeWindow = timeWindow(o.time, nextStart),
            nextRefreshAt = todayAt(nextStart),
          )
        }
      }
    }

    // After last
    val last = parsed[parsed.size - 1]
    val o = last.first
    val start = last.second

    val tomorrow = Calendar.getInstance()
    tomorrow.timeInMillis = Calendar.getInstance().timeInMillis
    tomorrow.set(Calendar.HOUR_OF_DAY, 0)
    tomorrow.set(Calendar.MINUTE, 1)
    tomorrow.set(Calendar.SECOND, 0)
    tomorrow.set(Calendar.MILLISECOND, 0)
    tomorrow.add(Calendar.DAY_OF_YEAR, 1)

    return Picked(
      activityId = o.activityId,
      weekId = o.weekId,
      dayId = o.dayId,
      time = o.time,
      title = o.title,
      timeStatus = timeStatus(start, nowMinutes),
      timeWindow = timeWindow(o.time, null),
      nextRefreshAt = tomorrow.timeInMillis,
    )
  }

  private class JSONObjectWrapper(private val obj: org.json.JSONObject) {
    val activityId: String get() = obj.optString("activityId", "")
    val weekId: String get() = obj.optString("weekId", "")
    val dayId: String get() = obj.optString("dayId", "")
    val time: String get() = obj.optString("time", "")
    val title: String get() = obj.optString("title", "")
  }

  private fun scheduleRefresh(context: Context, widgetIds: IntArray, triggerAtMillis: Long) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

    val intent = android.content.Intent(context, TaskWidgetProvider::class.java).apply {
      action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
      putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
    }

    val pi = PendingIntent.getBroadcast(
      context,
      0,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    // Make sure it's in the future.
    val now = System.currentTimeMillis()
    val at = if (triggerAtMillis <= now + 5_000) now + 10_000 else triggerAtMillis

    try {
      alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
    } catch (_: Exception) {
      // If exact alarms are restricted, fall back to inexact.
      try {
        alarmManager.set(AlarmManager.RTC_WAKEUP, at, pi)
      } catch (_: Exception) {
        // Ignore scheduling errors.
      }
    }
  }

  companion object {
    const val KEY_DAY_TASKS_JSON = "liflow_widget_day_tasks_json"
  }
}
