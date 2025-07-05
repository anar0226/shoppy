import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StoreSetupDialog extends StatefulWidget {
  final String storeId;

  const StoreSetupDialog({super.key, required this.storeId});

  @override
  State<StoreSetupDialog> createState() => _StoreSetupDialogState();
}

class _StoreSetupDialogState extends State<StoreSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _refundPolicyCtrl = TextEditingController();
  final _picker = ImagePicker();
  XFile? _logoFile;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _phoneCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _refundPolicyCtrl.dispose();
    super.dispose();
  }

  String? _validateContactInfo() {
    if (_phoneCtrl.text.trim().isEmpty &&
        _facebookCtrl.text.trim().isEmpty &&
        _instagramCtrl.text.trim().isEmpty) {
      return 'Дор хаяж нэг холбогдох арга заавал оруулна уу';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate contact information
    final contactError = _validateContactInfo();
    if (contactError != null) {
      setState(() => _error = contactError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String logoUrl = '';

      // Upload logo to Storage if provided
      if (_logoFile != null) {
        final fileName = _logoFile!.name;
        final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('stores/${widget.storeId}/logo.$ext');
        await storageRef.putData(await _logoFile!.readAsBytes());
        logoUrl = await storageRef.getDownloadURL();
      }

      // Update store document with new fields
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .update({
        'name': _storeNameCtrl.text.trim(),
        'logo': logoUrl,
        'phone': _phoneCtrl.text.trim(),
        'facebook': _facebookCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'refundPolicy': _refundPolicyCtrl.text.trim(),
        'status': 'active',
        'updatedAt': Timestamp.now(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      // Provide more descriptive messages based on error code
      String friendlyMsg;
      switch (e.code) {
        case 'permission-denied':
          friendlyMsg =
              'Permission denied: you are not allowed to perform this action.\nPlease ensure your account has the necessary store permissions.';
          break;
        case 'unauthenticated':
          friendlyMsg =
              'You are not signed in. Please sign-in again and retry.';
          break;
        default:
          friendlyMsg = 'Error (${e.code}): ${e.message ?? 'Unknown error.'}';
      }
      setState(() => _error = friendlyMsg);
    } catch (e) {
      // Fallback for any other error types
      setState(() => _error = 'Failed to setup store: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complete Your Store Setup',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Let\'s set up your store with a name and logo.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Store Name'),
                      TextFormField(
                        controller: _storeNameCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Enter your store name'),
                        validator: (v) => v != null && v.trim().isNotEmpty
                            ? null
                            : 'Required',
                      ),
                      const SizedBox(height: 16),
                      _label('Store Logo (Optional)'),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85);
                              if (picked != null) {
                                setState(() => _logoFile = picked);
                              }
                            },
                            icon: const Icon(Icons.photo, size: 18),
                            label: const Text('Choose Logo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_logoFile != null)
                            Expanded(
                              child: Text(_logoFile!.name,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Холбогдох мэдээлэл',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Дор хаяж нэг холбогдох арга заавал оруулна уу:',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      _label('Утасны дугаар (сонголттой)'),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                            hintText: 'жишээ: +976 9999 9999',
                            prefixIcon: Icon(Icons.phone)),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _label('Facebook хуудас (сонголттой)'),
                      TextFormField(
                        controller: _facebookCtrl,
                        decoration: const InputDecoration(
                            hintText: 'жишээ: facebook.com/yourstore',
                            prefixIcon: Icon(Icons.facebook)),
                      ),
                      const SizedBox(height: 16),
                      _label('Instagram хуудас (сонголттой)'),
                      TextFormField(
                        controller: _instagramCtrl,
                        decoration: const InputDecoration(
                            hintText: 'жишээ: @yourstore',
                            prefixIcon: Icon(Icons.camera_alt)),
                      ),
                      const SizedBox(height: 24),
                      _label('Буцаалт, Солилтын бодлого *'),
                      TextFormField(
                        controller: _refundPolicyCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            hintText:
                                'Таны дэлгүүрийн буцаалт, солилтын нөхцөл, шаардлагыг бичнэ үү...',
                            border: OutlineInputBorder()),
                        validator: (v) => v != null && v.trim().isNotEmpty
                            ? null
                            : 'Буцаалтын бодлого заавал оруулна уу',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Complete Setup'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );
}
