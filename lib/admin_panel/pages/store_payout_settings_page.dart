import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../features/stores/models/store_model.dart';
import '../../core/services/error_handler_service.dart';
import '../../core/utils/popup_utils.dart';

class StorePayoutSettingsPage extends StatefulWidget {
  final String storeId;

  const StorePayoutSettingsPage({super.key, required this.storeId});

  @override
  State<StorePayoutSettingsPage> createState() =>
      _StorePayoutSettingsPageState();
}

class _StorePayoutSettingsPageState extends State<StorePayoutSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  StoreModel? _storeModel;
  bool _isLoading = true;
  bool _isSaving = false;

  // Payout controllers
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankAccountHolderCtrl = TextEditingController();
  final _minimumPayoutAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Payout settings
  MongolianBank? _selectedBank;
  PayoutFrequency _selectedPayoutFrequency = PayoutFrequency.weekly;
  bool _autoPayoutEnabled = true;

  // KYC images
  String? _idCardFrontUrl;
  String? _idCardBackUrl;
  XFile? _idCardFrontFile;
  XFile? _idCardBackFile;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  @override
  void dispose() {
    _bankAccountNumberCtrl.dispose();
    _bankAccountHolderCtrl.dispose();
    _minimumPayoutAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .get();

      if (doc.exists) {
        _storeModel = StoreModel.fromFirestore(doc);

        // Initialize form fields
        _selectedBank = _storeModel!.selectedBank;
        _bankAccountNumberCtrl.text = _storeModel!.bankAccountNumber ?? '';
        _bankAccountHolderCtrl.text = _storeModel!.bankAccountHolderName ?? '';

        // Payout preferences
        _selectedPayoutFrequency = _storeModel!.payoutFrequency;
        _autoPayoutEnabled = _storeModel!.autoPayoutEnabled;
        _minimumPayoutAmountCtrl.text =
            _storeModel!.minimumPayoutAmount.toString();
        _notesCtrl.text = _storeModel!.payoutSetupNotes ?? '';

        // KYC images
        _idCardFrontUrl = _storeModel!.idCardFrontImage;
        _idCardBackUrl = _storeModel!.idCardBackImage;
      }
    } catch (e) {
      if (mounted) {
        await ErrorHandlerService.instance.handleError(
          operation: 'load_store_data',
          error: e,
          context: context,
          showUserMessage: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePayoutSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSaving = true);

      final updates = <String, dynamic>{
        'selectedBank': _selectedBank?.name,
        'bankAccountNumber': _bankAccountNumberCtrl.text.trim(),
        'bankAccountHolderName': _bankAccountHolderCtrl.text.trim(),
        'preferredPayoutMethod': PayoutMethod.bankTransfer.name,
        'payoutFrequency': _selectedPayoutFrequency.name,
        'autoPayoutEnabled': _autoPayoutEnabled,
        'minimumPayoutAmount':
            int.tryParse(_minimumPayoutAmountCtrl.text) ?? 50000,
        'payoutSetupNotes': _notesCtrl.text.trim(),
        'payoutSetupCompletedAt': FieldValue.serverTimestamp(),
      };

      // Update KYC images if new ones were uploaded
      if (_idCardFrontUrl != _storeModel?.idCardFrontImage) {
        updates['idCardFrontImage'] = _idCardFrontUrl;
        updates['kycStatus'] = KYCStatus.pending.name;
        updates['kycSubmittedAt'] = FieldValue.serverTimestamp();
      }
      if (_idCardBackUrl != _storeModel?.idCardBackImage) {
        updates['idCardBackImage'] = _idCardBackUrl;
        if (updates['kycStatus'] == null) {
          updates['kycStatus'] = KYCStatus.pending.name;
          updates['kycSubmittedAt'] = FieldValue.serverTimestamp();
        }
      }

      await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .update(updates);

      // Reload store data
      await _loadStoreData();

      if (mounted) {
        PopupUtils.showSuccess(
          context: context,
          message: 'Төлбөрийн тохиргоо амжилттай хадгалагдлаа!',
        );
      }
    } catch (e) {
      if (mounted) {
        await ErrorHandlerService.instance.handleError(
          operation: 'save_payout_settings',
          error: e,
          context: context,
          showUserMessage: true,
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<String> _uploadKYCImage(XFile imageFile, String side) async {
    final fileName = 'kyc_${side}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('stores/${widget.storeId}/kyc/$fileName');

    await ref.putFile(File(imageFile.path));
    return await ref.getDownloadURL();
  }

  Future<void> _pickImage(String side) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (side == 'front') {
            _idCardFrontFile = pickedFile;
          } else {
            _idCardBackFile = pickedFile;
          }
        });

        // Upload image
        final url = await _uploadKYCImage(pickedFile, side);
        setState(() {
          if (side == 'front') {
            _idCardFrontUrl = url;
          } else {
            _idCardBackUrl = url;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        await ErrorHandlerService.instance.handleError(
          operation: 'pick_kyc_image',
          error: e,
          context: context,
          showUserMessage: true,
        );
      }
    }
  }

  double _getPayoutSetupProgress() {
    if (_storeModel == null) return 0.0;
    return _storeModel!.payoutSetupProgress;
  }

  String _getProgressMessage(double progress) {
    if (progress == 100) return 'Төлбөрийн тохиргоо Амжилттай!';
    if (progress >= 75) return '75%';
    if (progress >= 50) return '50%';
    if (progress >= 25) return '25%';
    return 'Төлбөрийн тохиргоогоо эхлүүлцгээе';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_storeModel == null) {
      return const Center(child: Text('Дэлгүүр олдсонгүй'));
    }

    final progress = _getPayoutSetupProgress();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.payment, color: Colors.blue.shade600, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Төлбөрийн тохиргоо',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Банкны дансны мэдээлэл болон KYC баримт',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Progress indicator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Төлбөрийн тохиргооны явц',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${progress.toInt()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getProgressMessage(progress),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bank account details
            _buildBankSection(),
            const SizedBox(height: 24),

            // Payout preferences
            _buildPayoutPreferencesSection(),
            const SizedBox(height: 24),

            // KYC documents
            _buildKYCSection(),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePayoutSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Төлбөрийн тохиргоог хадгалах',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Банкны дансны мэдээлэл',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Иргэний үнэмлэхний тод зургийг (урд болон хойд тал) байршуулна уу.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MongolianBank>(
              value: _selectedBank,
              decoration: const InputDecoration(
                labelText: 'Банк *',
                border: OutlineInputBorder(),
              ),
              items: MongolianBank.values.map((bank) {
                return DropdownMenuItem(
                  value: bank,
                  child: Text(bank.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedBank = value);
              },
              validator: (value) {
                if (value == null) return 'Банк сонгоно уу';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bankAccountNumberCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Дансны дугаар *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Дансны дугаар оруулна уу';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _bankAccountHolderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Дансны эзэмшигчийн нэр *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Дансны эзэмшигчийн нэр оруулна уу';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Төлбөрийн тохиргоо',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PayoutFrequency>(
              value: _selectedPayoutFrequency,
              decoration: const InputDecoration(
                labelText: 'Төлбөрийн давтамж',
                border: OutlineInputBorder(),
              ),
              items: PayoutFrequency.values.map((frequency) {
                return DropdownMenuItem(
                  value: frequency,
                  child: Text(frequency.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPayoutFrequency = value!);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minimumPayoutAmountCtrl,
              decoration: const InputDecoration(
                labelText: 'Хамгийн бага төлбөрийн хэмжээ (₮)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Хамгийн бага хэмжээ оруулна уу';
                }
                final amount = int.tryParse(value!);
                if (amount == null || amount <= 0) {
                  return 'Зөв хэмжээ оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Автомат төлбөр'),
              subtitle: const Text('Төлбөрийг автоматаар илгээх'),
              value: _autoPayoutEnabled,
              onChanged: (value) {
                setState(() => _autoPayoutEnabled = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Нэмэлт тэмдэглэл (Заавал биш)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKYCSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text(
                  'KYC баримт',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Иргэний үнэмлэхний тод зургийг (урд болон хойд тал) байршуулна уу.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage('front'),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Урд тал'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                        ),
                      ),
                      if (_idCardFrontUrl != null || _idCardFrontFile != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(Icons.check_circle, color: Colors.green),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage('back'),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Хойд тал'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                        ),
                      ),
                      if (_idCardBackUrl != null || _idCardBackFile != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(Icons.check_circle, color: Colors.green),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
