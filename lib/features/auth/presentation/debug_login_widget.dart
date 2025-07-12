import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug login widget for testing purposes
/// Only shown in debug mode
class DebugLoginWidget extends StatelessWidget {
  const DebugLoginWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.red[600], size: 16),
              const SizedBox(width: 8),
              Text(
                'DEBUG MODE - Testing Only',
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Quick test login for development:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 36),
            ),
            onPressed: () => _debugLogin(context),
            child: const Text('Debug Login (Anar0226@gmail.com)'),
          ),
          const SizedBox(height: 8),
          Text(
            'This will create/login to test account',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _debugLogin(BuildContext context) async {
    try {
      final email = 'Anar0226@gmail.com';
      final password = 'TestPassword123!'; // Strong password for testing

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating/logging into test account...'),
            ],
          ),
        ),
      );

      UserCredential? userCredential;

      try {
        // Try to sign in first
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Create the account if it doesn't exist
          userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Update display name
          await userCredential.user?.updateDisplayName('Test User (Anar)');

          // Send verification email
          await userCredential.user?.sendEmailVerification();

          // Create user document
          await _createTestUserDocument(userCredential.user!);
        } else {
          throw e;
        }
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (userCredential?.user != null) {
        // Show success and navigate
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                userCredential!.user!.emailVerified
                    ? 'Debug login successful!'
                    : 'Debug account created! Check email for verification.',
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to home
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTestUserDocument(User user) async {
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Check if document already exists
      final snap = await doc.get();
      if (snap.exists) {
        // Just update last seen
        await doc.update({
          'lastSeen': FieldValue.serverTimestamp(),
          'lastLoginMethod': 'debug',
        });
        return;
      }

      // Create new user document
      await doc.set({
        'displayName': 'Test User (Anar)',
        'email': user.email ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
        'lastLoginMethod': 'debug',
        'followerStoreIds': [],
        'pushTokens': [],
        'savedProductIds': [],
        'isEmailVerified': user.emailVerified,
        'isPhoneVerified': false,
        'userType': 'customer',
        'isActive': true,
        'isBlocked': false,
        'securityProfile': {
          'passwordChangeRequired': false,
          'twoFactorEnabled': false,
          'lastPasswordChange': FieldValue.serverTimestamp(),
        },
        // Add some test data
        'debugAccount': true,
        'testingMode': true,
      });
    } catch (e) {
      debugPrint('Error creating test user document: $e');
    }
  }
}

/// Quick debug login function for one-liner usage
class DebugAuth {
  static Future<bool> quickLogin(BuildContext context) async {
    try {
      final email = 'Anar0226@gmail.com';
      final password = 'TestPassword123!';

      UserCredential? userCredential;

      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          userCredential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          await userCredential.user?.updateDisplayName('Test User (Anar)');
          await userCredential.user?.sendEmailVerification();
        } else {
          throw e;
        }
      }

      return userCredential?.user != null;
    } catch (e) {
      debugPrint('Quick debug login failed: $e');
      return false;
    }
  }
}
