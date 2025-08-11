import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'admin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  String envFile;
  const String flutterEnv =
      String.fromEnvironment('FLUTTER_ENV', defaultValue: '');

  if (flutterEnv == 'local-release') {
    envFile = 'assets/env/local-release.env';
  } else if (kReleaseMode) {
    const bool isCICD = bool.fromEnvironment('CI', defaultValue: false);
    if (isCICD) {
      envFile = 'assets/env/prod.env';
    } else {
      envFile = 'assets/env/local-release.env';
    }
  } else {
    envFile = 'assets/env/dev.env';
  }

  debugPrint('🔧 Loading environment from: $envFile');
  await dotenv.load(fileName: envFile);

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const AdminApp());
}
