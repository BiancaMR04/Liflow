import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';
import 'firestore_activity_service.dart';
import 'notification_service.dart';
import 'widget_task_snapshot_service.dart';

/// Widget interactivity callback.
///
/// This is invoked by Android widget taps and iOS 17 interactive widget buttons.
///
/// IMPORTANT:
/// - Keep it fast and side-effect focused.
/// - It may run while the app is not in the foreground.
/// - Firebase must be configured (FlutterFire) for Firestore calls to succeed.
@pragma('vm:entry-point')
class WidgetInteractivity {
  /// The cutoff used by the widget (kept simple/constant for now).
  ///
  /// You can later make this user-configurable and persist it.
  static const String cutoffTime = '12:00';

  @pragma('vm:entry-point')
  static FutureOr<void> callback(Uri? uri) async {
    if (uri == null) return;

    WidgetsFlutterBinding.ensureInitialized();

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await HomeWidget.setAppGroupId('group.com.example.liflow');
    }

    // Initialize Firebase if available.
    // If Firebase isn't configured yet, this will throw; we fail gracefully.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      return;
    }

    // Ensure authenticated requests (keeps UX "no-login" via anonymous auth).
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (_) {
        return;
      }
    }

    final firestore = FirestoreActivityService();
    final widgetSnapshot = WidgetTaskSnapshotService(firestore);

    // liflow://widget/markDone?weekId=...&dayId=...&activityId=...
    if (uri.host == 'widget' && uri.path == '/markDone') {
      final weekId = uri.queryParameters['weekId'];
      final dayId = uri.queryParameters['dayId'];
      final activityId = uri.queryParameters['activityId'];

      if (weekId == null || dayId == null || activityId == null) return;
      if (weekId.isEmpty || dayId.isEmpty || activityId.isEmpty) return;

      await firestore.setActivityDone(
        weekId: weekId,
        dayId: dayId,
        activityId: activityId,
        done: true,
      );

      try {
        await NotificationService.instance.cancelForActivity(
          weekId: weekId,
          dayId: dayId,
          activityId: activityId,
        );
      } catch (_) {
        // Marking the task done is the important part; notification cleanup is best effort.
      }

      // Refresh widget snapshot so the completed task disappears.
      await widgetSnapshot.updateForDay(
        weekId: weekId,
        dayId: dayId,
        date: DateTime.now(),
        cutoffTime: cutoffTime,
      );

      return;
    }
  }

  static Future<void> register() async {
    await HomeWidget.registerInteractivityCallback(callback);
  }
}
