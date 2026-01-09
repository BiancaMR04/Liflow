/// Keys used to sync data between Flutter and the Android home screen widget.
class WidgetKeys {
  static const String title = 'liflow_widget_title';
  static const String subtitle = 'liflow_widget_subtitle';
  static const String tasksJson = 'liflow_widget_tasks_json';

  // iOS widget (WidgetKit) uses a simpler payload: pending tasks for the day.
  // The widget itself decides which one is "current" based on the time.
  static const String dayTasksJson = 'liflow_widget_day_tasks_json';
}
