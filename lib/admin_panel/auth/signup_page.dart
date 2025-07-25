import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/subscription_payment_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    UserCredential? userCredential;
    String? storeId;

    try {
      // Step 1: Create user in Firebase Authentication
      userCredential = await AuthService.instance
          .signUp(_emailCtrl.text.trim(), _passCtrl.text.trim());

      if (userCredential.user == null) {
        throw Exception('Failed to create user account');
      }

      // Step 2: Create store document in Firestore
      storeId = FirebaseFirestore.instance.collection('stores').doc().id;
      await FirebaseFirestore.instance.collection('stores').doc(storeId).set({
        'name': 'Шинэ дэлгүүр', // Temporary name to satisfy Firestore rules
        'description': '',
        'logo': '',
        'banner': '',
        'ownerId': userCredential.user!.uid,
        'status': 'setup_pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'settings': {},
        'phone': '',
        'facebook': '',
        'instagram': '',
        'refundPolicy': '',
        // Initialize payout fields as empty
        'selectedBank': null,
        'bankAccountNumber': '',
        'bankAccountHolderName': '',
        'preferredPayoutMethod': 'bankTransfer',
        'payoutFrequency': 'weekly',
        'minimumPayoutAmount': 50000,
        'autoPayoutEnabled': true,
        'idCardFrontImage': '',
        'idCardBackImage': '',
        'kycStatus': 'notSubmitted',
        'kycRejectionReason': '',
        'kycSubmittedAt': null,
        'kycApprovedAt': null,
        'payoutSetupCompleted': false,
        'payoutSetupCompletedAt': null,
        'payoutSetupNotes': '',
        // Initialize subscription fields
        'subscriptionStatus': 'pending',
        'subscriptionStartDate': null,
        'subscriptionEndDate': null,
        'lastPaymentDate': null,
        'nextPaymentDate': null,
        'paymentHistory': [],
      });

      // Step 3: Navigate to subscription payment page
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => SubscriptionPaymentPage(
                  storeId: storeId,
                  userId: userCredential?.user?.uid,
                )));
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Auth specific errors
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Нууц үг хэтэрхий хялбар байна';
          break;
        case 'email-already-in-use':
          errorMessage = 'Энэ и-мэйл хаяг аль хэдийн бүртгэгдсэн байна';
          break;
        case 'invalid-email':
          errorMessage = 'И-мэйл хаягийн хэлбэр буруу байна';
          break;
        case 'operation-not-allowed':
          errorMessage = 'И-мэйл/нууц үгээр бүртгүүлэх боломжгүй байна';
          break;
        default:
          errorMessage = e.message ?? 'Бүртгүүлэхэд алдаа гарлаа';
      }
      setState(() => _error = errorMessage);
    } catch (e) {
      // Handle other errors (likely Firestore errors)
      developer.log('Signup error: $e', name: 'SignupPage');

      // If user was created but Firestore failed, we need to clean up
      if (userCredential?.user != null) {
        try {
          // Delete the user from Firebase Auth to allow retry
          await userCredential?.user?.delete();
          setState(
              () => _error = 'Бүртгүүлэхэд алдаа гарлаа. Дахин оролдоно уу.');
        } catch (deleteError) {
          developer.log(
              'Failed to delete user after signup error: $deleteError',
              name: 'SignupPage');
          // If we can't delete the user, inform them to try logging in instead
          setState(() => _error =
              'Бүртгүүлэх явцад алдаа гарлаа. Та нэвтрэх оролдоод үзээрэй.');
        }
      } else {
        setState(() => _error = 'Бүртгүүлэхэд алдаа гарлаа');
      }

      // Also clean up any partial Firestore data
      if (storeId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .delete();
        } catch (cleanupError) {
          developer.log('Failed to cleanup Firestore data: $cleanupError',
              name: 'SignupPage');
          // Ignore cleanup errors
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Шинээр бүртгүүлэх',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'И-мэйл хаяг'),
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'И-мэйл хаяг оруулна уу',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Нууц үг'),
                    validator: (v) => v != null && v.length >= 6
                        ? null
                        : '6-н тэмдэгтээс дээш нууц үг оруулна уу',
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Text('Бүртгүүлэх'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Шууд нэвтрэх'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
