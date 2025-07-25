import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../features/stores/models/store_model.dart';

class StoreSetupDialog extends StatefulWidget {
  final String storeId;

  const StoreSetupDialog({super.key, required this.storeId});

  @override
  State<StoreSetupDialog> createState() => _StoreSetupDialogState();
}

class _StoreSetupDialogState extends State<StoreSetupDialog> {
  final _formKey = GlobalKey<FormState>();

  // Store basic info controllers
  final _storeNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _refundPolicyCtrl = TextEditingController();

  // Payout controllers
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankAccountHolderNameCtrl = TextEditingController();
  final _minimumPayoutAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _picker = ImagePicker();
  XFile? _logoFile;
  XFile? _idCardFrontFile;
  XFile? _idCardBackFile;

  // Form state
  bool _loading = false;
  String? _error;
  int _currentStep = 0;

  // Payout settings
  MongolianBank? _selectedBank;
  PayoutMethod _preferredPayoutMethod = PayoutMethod.bankTransfer;
  PayoutFrequency _payoutFrequency = PayoutFrequency.weekly;
  bool _autoPayoutEnabled = true;

  // KYC status
  final KYCStatus _kycStatus = KYCStatus.pending;

  @override
  void initState() {
    super.initState();
    _minimumPayoutAmountCtrl.text = '50000'; // Default minimum amount
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _phoneCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _refundPolicyCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankAccountHolderNameCtrl.dispose();
    _minimumPayoutAmountCtrl.dispose();
    _notesCtrl.dispose();
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

  String? _validatePayoutInfo() {
    if (_selectedBank == null) {
      return 'Банк сонгоно уу';
    }
    if (_bankAccountNumberCtrl.text.trim().isEmpty) {
      return 'Банкны дансны дугаар заавал оруулна уу';
    }
    if (_bankAccountHolderNameCtrl.text.trim().isEmpty) {
      return 'Дансны эзэмшигчийн нэр заавал оруулна уу';
    }

    if (_idCardFrontFile == null || _idCardBackFile == null) {
      return 'Иргэний үнэмлэхний урд болон хойд талын зураг заавал оруулна уу';
    }

    return null;
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      // Validate store basic info
      if (!_formKey.currentState!.validate()) return;

      final contactError = _validateContactInfo();
      if (contactError != null) {
        setState(() => _error = contactError);
        return;
      }

      setState(() {
        _currentStep = 1;
        _error = null;
      });
    } else if (_currentStep == 1) {
      // Validate payout info
      final payoutError = _validatePayoutInfo();
      if (payoutError != null) {
        setState(() => _error = payoutError);
        return;
      }

      // Save everything
      await _save();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String logoUrl = '';
      String idCardFrontUrl = '';
      String idCardBackUrl = '';

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

      // Upload ID card images
      if (_idCardFrontFile != null) {
        final fileName = _idCardFrontFile!.name;
        final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('stores/${widget.storeId}/kyc/front.$ext');
        await storageRef.putData(await _idCardFrontFile!.readAsBytes());
        idCardFrontUrl = await storageRef.getDownloadURL();
      }

      if (_idCardBackFile != null) {
        final fileName = _idCardBackFile!.name;
        final ext = fileName.contains('.') ? fileName.split('.').last : 'png';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('stores/${widget.storeId}/kyc/back.$ext');
        await storageRef.putData(await _idCardBackFile!.readAsBytes());
        idCardBackUrl = await storageRef.getDownloadURL();
      }

      // Update store document with all fields
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .update({
        // Basic store info
        'name': _storeNameCtrl.text.trim(),
        'logo': logoUrl,
        'phone': _phoneCtrl.text.trim(),
        'facebook': _facebookCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'refundPolicy': _refundPolicyCtrl.text.trim(),
        'status': 'active',

        // Payout information
        'selectedBank': _selectedBank?.name,
        'bankAccountNumber': _bankAccountNumberCtrl.text.trim(),
        'bankAccountHolderName': _bankAccountHolderNameCtrl.text.trim(),
        'preferredPayoutMethod': _preferredPayoutMethod.name,
        'payoutFrequency': _payoutFrequency.name,
        'minimumPayoutAmount':
            double.tryParse(_minimumPayoutAmountCtrl.text) ?? 50000,
        'autoPayoutEnabled': _autoPayoutEnabled,

        // KYC information
        'idCardFrontImage': idCardFrontUrl,
        'idCardBackImage': idCardBackUrl,
        'kycStatus': _kycStatus.name,
        'kycSubmittedAt': Timestamp.now(),

        // Payout setup status
        'payoutSetupCompleted': true,
        'payoutSetupCompletedAt': Timestamp.now(),
        'payoutSetupNotes': _notesCtrl.text.trim(),

        'updatedAt': Timestamp.now(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
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
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with progress indicator
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _currentStep == 0 ? Icons.store : Icons.payment,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentStep == 0
                              ? 'Дэлгүүрийн үндсэн мэдээлэл'
                              : 'Төлбөрийн тохиргоо',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / 2,
                    backgroundColor: Colors.grey.shade300,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Алхам ${_currentStep + 1}/2',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: _currentStep == 0
                      ? _buildBasicInfoStep()
                      : _buildPayoutStep(),
                ),
              ),
            ),

            // Footer with buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: _loading ? null : _previousStep,
                          child: const Text('Өмнөх'),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: _loading ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_currentStep == 0 ? 'Дараах' : 'Дуусгах'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Дэлгүүрийн үндсэн мэдээлэл',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Дэлгүүрийн нэр, лого, холбогдох мэдээлэлээ оруулна уу.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 24),
        _label('Дэлгүүрийн нэр *'),
        TextFormField(
          controller: _storeNameCtrl,
          decoration: const InputDecoration(
            hintText: 'Дэлгүүрийн нэрээ оруулна уу',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v != null && v.trim().isNotEmpty
              ? null
              : 'Дэлгүүрийн нэр заавал оруулна уу',
        ),
        const SizedBox(height: 16),
        _label('Дэлгүүрийн лого (заавал биш)'),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() => _logoFile = picked);
                }
              },
              icon: const Icon(Icons.photo, size: 18),
              label: const Text('Лого сонгох'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_logoFile != null)
              Expanded(
                child: Text(
                  _logoFile!.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Холбогдох мэдээлэл',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Дор хаяж нэг холбогдох арга заавал оруулна уу:',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        _label('Утасны дугаар (заавал биш)'),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(
            hintText: 'жишээ: +976 9999 9999',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _label('Facebook хуудас (заавал биш)'),
        TextFormField(
          controller: _facebookCtrl,
          decoration: const InputDecoration(
            hintText: 'жишээ: facebook.com/yourstore',
            prefixIcon: Icon(Icons.facebook),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _label('Instagram хуудас (заавал биш)'),
        TextFormField(
          controller: _instagramCtrl,
          decoration: const InputDecoration(
            hintText: 'жишээ: @yourstore',
            prefixIcon: Icon(Icons.camera_alt),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        _label('Буцаалт, Солилт'),
        TextFormField(
          controller: _refundPolicyCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Та буцаалт, солилтын нөхцөл, шаардлагыг бичнэ үү...',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              v != null && v.trim().isNotEmpty ? null : 'заавал оруулна уу',
        ),
      ],
    );
  }

  Widget _buildPayoutStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Төлбөрийн тохиргоо',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Борлуулалтаас олсон орлогоо хүлээн авахын тулд төлбөрийн мэдээлэлээ тохируулна уу.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 24),

        // Payout method selection
        _label('Төлбөрийн арга *'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                RadioListTile<PayoutMethod>(
                  title: const Text('Банкны данс'),
                  subtitle: const Text('Шууд банкны данс руу төлбөр'),
                  value: PayoutMethod.bankTransfer,
                  groupValue: _preferredPayoutMethod,
                  onChanged: (value) {
                    setState(() {
                      _preferredPayoutMethod = value!;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Bank account details
        _label('Банкны мэдээлэл *'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _label('Банк *'),
                DropdownButtonFormField<MongolianBank>(
                  value: _selectedBank,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Банк сонгоно уу',
                  ),
                  items: MongolianBank.values.map((bank) {
                    return DropdownMenuItem(
                      value: bank,
                      child: Text(bank.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBank = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _label('Дансны дугаар *'),
                TextFormField(
                  controller: _bankAccountNumberCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Дансны дугаараа оруулна уу',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _label('Дансны эзэмшигчийн нэр *'),
                TextFormField(
                  controller: _bankAccountHolderNameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Дансны эзэмшигчийн нэрийг оруулна уу',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Payout preferences
        _label('Төлбөрийн тохиргоо'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _label('Төлбөрийн давтамж'),
                DropdownButtonFormField<PayoutFrequency>(
                  value: _payoutFrequency,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: PayoutFrequency.values.map((frequency) {
                    return DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _payoutFrequency = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _label('Хамгийн бага төлбөрийн хэмжээ (₮)'),
                TextFormField(
                  controller: _minimumPayoutAmountCtrl,
                  decoration: const InputDecoration(
                    hintText: '50000',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Автомат төлбөр'),
                  subtitle: const Text('Төлбөрийг автоматаар илгээх'),
                  value: _autoPayoutEnabled,
                  onChanged: (value) {
                    setState(() {
                      _autoPayoutEnabled = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // KYC documents
        _label('Иргэний үнэмлэхний зураг *'),
        const Text(
          'Иргэний үнэмлэхний тод зургийг (урд болон хойд тал) байршуулна уу.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Урд тал'),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setState(() => _idCardFrontFile = picked);
                      }
                    },
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Урд талыг байршуулах'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _idCardFrontFile != null
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      foregroundColor: _idCardFrontFile != null
                          ? Colors.green.shade800
                          : Colors.black87,
                    ),
                  ),
                  if (_idCardFrontFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _idCardFrontFile!.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Хойд тал'),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setState(() => _idCardBackFile = picked);
                      }
                    },
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Хойд талыг байршуулах'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _idCardBackFile != null
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      foregroundColor: _idCardBackFile != null
                          ? Colors.green.shade800
                          : Colors.black87,
                    ),
                  ),
                  if (_idCardBackFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _idCardBackFile!.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        _label('Нэмэлт тэмдэглэл (заавал биш)'),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Нэмэлт тэмдэглэл оруулна уу...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
}
