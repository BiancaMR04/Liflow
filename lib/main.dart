import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';

import 'firebase_options.dart';
import 'services/widget_interactivity.dart';
import 'screens/home_shell.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS WidgetKit needs an App Group to share data between the app and the widget.
  // This must match the App Group configured in Xcode (Signing & Capabilities).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await HomeWidget.setAppGroupId('group.com.example.liflow');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Many Firestore security rules require authenticated requests.
  // We keep the app "no-login" by using anonymous auth.
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (_) {
      // If auth fails, the app can still render, but Firestore ops may fail.
    }
  }

  // Enables widget interactivity callbacks.
  await WidgetInteractivity.register();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liflow',
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
