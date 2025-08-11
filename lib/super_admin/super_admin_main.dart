import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../firebase_options.dart';
import 'super_admin_app.dart';

/// Main entry point for the Super Admin panel
///
/// This runs as a separate app from the main Avii.mn app
/// Usage: flutter run -t lib/super_admin/super_admin_main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // Environment file not found, using default configuration
  }

  // Initialize Firebase once
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  runApp(const SuperAdminApp());
}

/// Helper function to access Super Admin from main app (for development)
Widget buildSuperAdminDebugButton(BuildContext context) {
  return FloatingActionButton.extended(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SuperAdminApp(),
        ),
      );
    },
    label: const Text('Super Admin'),
    icon: const Icon(Icons.admin_panel_settings),
    backgroundColor: Colors.red.shade600,
  );
}
