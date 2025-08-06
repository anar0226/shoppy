import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../../features/stores/models/store_model.dart';
import '../../core/services/error_handler_service.dart';
import '../../core/services/qpay_service.dart';
import '../../core/utils/popup_utils.dart';
import '../../core/utils/order_id_generator.dart';
import '../../features/settings/themes/app_themes.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import 'custom_payment_page.dart';

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
  final QPayService _qpayService = QPayService();

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
        updates['kycStatus'] = KYCStatus.pending;
        updates['kycSubmittedAt'] = FieldValue.serverTimestamp();
      }
      if (_idCardBackUrl != _storeModel?.idCardBackImage) {
        updates['idCardBackImage'] = _idCardBackUrl;
        if (updates['kycStatus'] == null) {
          updates['kycStatus'] = KYCStatus.pending;
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
      // Check if KYC is already submitted and in process
      if (_storeModel?.kycStatus == KYCStatus.pending ||
          _storeModel?.kycStatus == KYCStatus.approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Таны баталгаажуулалт хүлээгдэж байна. Дахин илгээх шаардлагагүй.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if the specific side image is already uploaded
      final existingImageUrl =
          side == 'front' ? _idCardFrontUrl : _idCardBackUrl;
      if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${side == 'front' ? 'Урд' : 'Ар'} талын зураг аль хэдийн оруулсан байна.'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

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

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${side == 'front' ? 'Урд' : 'Ар'} талын зураг амжилттай орууллаа'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Зураг оруулахад алдаа гарлаа. Дахин оролдоно уу.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Row(
          children: [
            SideMenu(selected: 'Төлбөрийн тохиргоо'),
            Expanded(
              child: Column(
                children: [
                  TopNavBar(title: 'Төлбөрийн тохиргоо'),
                  Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_storeModel == null) {
      return const Scaffold(
        body: Row(
          children: [
            SideMenu(selected: 'Төлбөрийн тохиргоо'),
            Expanded(
              child: Column(
                children: [
                  TopNavBar(title: 'Төлбөрийн тохиргоо'),
                  Expanded(
                    child: Center(child: Text('Дэлгүүр олдсонгүй')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          const SideMenu(selected: 'Төлбөрийн тохиргоо'),
          Expanded(
            child: Column(
              children: [
                const TopNavBar(title: 'Төлбөрийн тохиргоо'),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // 1. Банкны дансны мэдээлэл
                          _buildBankAccountSection(),
                          const SizedBox(height: 24),

                          // 2. KYC Баталгаажуулалт
                          _buildKYCSection(),
                          const SizedBox(height: 24),

                          // 3. Сарын хураамж
                          _buildSubscriptionSection(),
                          const SizedBox(height: 32),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _savePayoutSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4285F4),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
                                      'Тохиргоо хадгалах',
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            children: [
              const Icon(Icons.account_balance,
                  color: Color(0xFF4285F4), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Банкны дансны мэдээлэл',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning,
                        color: Colors.orange.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Баталгаажуулалт хүлээгдэж байна',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bank selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Банк сонгох',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppThemes.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MongolianBank>(
                value: _selectedBank,
                decoration: InputDecoration(
                  hintText: 'Банкаа сонгоно уу',
                  hintStyle: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppThemes.getBorderColor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppThemes.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4285F4)),
                  ),
                  suffixIcon: Icon(Icons.keyboard_arrow_down,
                      color: AppThemes.getSecondaryTextColor(context)),
                  fillColor: AppThemes.getSurfaceColor(context),
                  filled: true,
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
            ],
          ),
          const SizedBox(height: 16),

          // Account number
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Дансны дугаар',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppThemes.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bankAccountNumberCtrl,
                decoration: InputDecoration(
                  hintText: 'Дансны дугаараа оруулна уу',
                  hintStyle: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)),
                  prefixIcon: Icon(Icons.credit_card,
                      color: AppThemes.getSecondaryTextColor(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppThemes.getBorderColor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppThemes.getBorderColor(context)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide(color: Color(0xFF4285F4)),
                  ),
                  fillColor: AppThemes.getSurfaceColor(context),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Дансны дугаар оруулна уу';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Account holder name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Дансны эзэмшигчийн нэр',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppThemes.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bankAccountHolderCtrl,
                decoration: InputDecoration(
                  hintText: 'Дансны эзэмшигчийн нэрийг оруулна уу',
                  hintStyle: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)),
                  prefixIcon: Icon(Icons.person,
                      color: AppThemes.getSecondaryTextColor(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppThemes.getBorderColor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppThemes.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4285F4)),
                  ),
                  fillColor: AppThemes.getSurfaceColor(context),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Дансны эзэмшигчийн нэр оруулна уу';
                  }
                  return null;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKYCSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            children: [
              const Icon(Icons.verified_user,
                  color: Color(0xFF4285F4), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'КҮС Баталгаажуулалт',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppThemes.getTextColor(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning,
                        color: Colors.orange.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Баталгаажуулалт хүлээгдэж байна',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Upload sections
          Row(
            children: [
              // Front side
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppThemes.getBorderColor(context),
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Иргэний үнэмлэх (Урд тал)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppThemes.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Icon(
                        Icons.cloud_upload,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Иргэний үнэмлэхийн урд талыг оруулна уу',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppThemes.getSecondaryTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_idCardFrontUrl != null &&
                                      _idCardFrontUrl!.isNotEmpty) ||
                                  (_storeModel?.kycStatus ==
                                          KYCStatus.pending ||
                                      _storeModel?.kycStatus ==
                                          KYCStatus.approved)
                              ? null
                              : () => _pickImage('front'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_idCardFrontUrl != null &&
                                        _idCardFrontUrl!.isNotEmpty) ||
                                    (_storeModel?.kycStatus ==
                                            KYCStatus.pending ||
                                        _storeModel?.kycStatus ==
                                            KYCStatus.approved)
                                ? Colors.grey
                                : const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            (_idCardFrontUrl != null &&
                                    _idCardFrontUrl!.isNotEmpty)
                                ? 'Оруулсан'
                                : (_storeModel?.kycStatus ==
                                            KYCStatus.pending ||
                                        _storeModel?.kycStatus ==
                                            KYCStatus.approved)
                                    ? 'Хүлээгдэж байна'
                                    : 'Файл сонгох',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (_idCardFrontUrl != null || _idCardFrontFile != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Back side
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppThemes.getBorderColor(context),
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Иргэний үнэмлэх (Ар тал)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppThemes.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Icon(
                        Icons.cloud_upload,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Иргэний үнэмлэхийн ар талыг оруулна уу',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppThemes.getSecondaryTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_idCardBackUrl != null &&
                                      _idCardBackUrl!.isNotEmpty) ||
                                  (_storeModel?.kycStatus ==
                                          KYCStatus.pending ||
                                      _storeModel?.kycStatus ==
                                          KYCStatus.approved)
                              ? null
                              : () => _pickImage('back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_idCardBackUrl != null &&
                                        _idCardBackUrl!.isNotEmpty) ||
                                    (_storeModel?.kycStatus ==
                                            KYCStatus.pending ||
                                        _storeModel?.kycStatus ==
                                            KYCStatus.approved)
                                ? Colors.grey
                                : const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            (_idCardBackUrl != null &&
                                    _idCardBackUrl!.isNotEmpty)
                                ? 'Оруулсан'
                                : (_storeModel?.kycStatus ==
                                            KYCStatus.pending ||
                                        _storeModel?.kycStatus ==
                                            KYCStatus.approved)
                                    ? 'Хүлээгдэж байна'
                                    : 'Файл сонгох',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (_idCardBackUrl != null || _idCardBackFile != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KYC Requirements
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4285F4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Color(0xFF4285F4), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'КҮС шаардлага',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppThemes.getTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Тод, чанартай зураг оруулна уу',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Бүх үсэг, тоо уншигдахуйц байх',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Зөвхөн төрийн байгууллагын олгосон үнэмлэх ашиглана уу',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Баталгаажуулалт ихэвчлэн 1 ажлын өдөр шаардагдана',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQPayPayment() async {
    try {
      debugPrint('=== Starting payment process ===');
      debugPrint('Store ID: ${widget.storeId}');
      debugPrint('Store Model: ${_storeModel?.name}');
      debugPrint('Mounted: $mounted');

      // Validate required data
      if (widget.storeId.isEmpty) {
        throw Exception('Store ID is empty');
      }

      // Check if there's already a pending payment for this store
      final existingPaymentsSnapshot = await FirebaseFirestore.instance
          .collection('store_subscriptions')
          .doc(widget.storeId)
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      String orderId;

      if (existingPaymentsSnapshot.docs.isNotEmpty) {
        // Use existing pending payment
        final existingPayment = existingPaymentsSnapshot.docs.first;
        orderId = existingPayment.data()['orderId'];
        debugPrint('Found existing pending payment: $orderId');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Хүлээгдэж буй төлбөр байна. Үргэлжлүүлж байна...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Generate new unique order ID for subscription payment
        orderId =
            'SUB_${widget.storeId}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
        debugPrint('Generated new Order ID: $orderId');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Шинэ төлбөр үүсгэж байна...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Navigate to custom payment page
      if (mounted) {
        debugPrint('Navigating to CustomPaymentPage...');
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CustomPaymentPage(
              storeId: widget.storeId,
              amount: 200.0, // 200 MNT
              description: 'Сарын хураамж - ${_storeModel?.name ?? 'Дэлгүүр'}',
              orderId: orderId,
            ),
          ),
        );
        debugPrint('Navigation result: $result');
      }
    } catch (e, stackTrace) {
      debugPrint('=== Payment Error ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Төлбөр эхлүүлэхэд алдаа гарлаа: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Дахин оролдох',
              textColor: Colors.white,
              onPressed: () => _handleQPayPayment(),
            ),
          ),
        );
      }
    }
  }

  Widget _buildSubscriptionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: Color(0xFF4285F4), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Сарын хураамж',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppThemes.getTextColor(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Төлөөгүй',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Subscription overview
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сарын хураамж төлбөрийн дүн',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemes.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '₮ 25,000',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Дараагийн төлбөрийн огноо',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemes.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Тодорхойгүй',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppThemes.getTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // QPay payment section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                  color: const Color(0xFF4285F4),
                  style: BorderStyle.solid,
                  width: 2),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                  : Colors.blue.shade50,
            ),
            child: Column(
              children: [
                // QPay icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Q',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Сарын хураамжаа төлөх',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppThemes.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Сарын хураамжаа дансанд шилжүүлэх',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppThemes.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleQPayPayment,
                    icon: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'Q',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    label: const Text(
                      'Сарын хураамжаа төлөх',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Сарын хураамж төлбөр: 25,000 ₮',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemes.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF4285F4).withValues(alpha: 0.1)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4285F4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Color(0xFF4285F4), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Төлбөрийн заавар',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppThemes.getTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•Та сар бүрийн эхээр төлнө үү',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• QPay апп-ээр хурдан, аюулгүй төлбөр хийх боломжтой',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Төлбөр хийснээс хойш үйлчилгээ шууд идэвхжинэ',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Асуудал гарвал тусламжийн төвтэй холбогдоно уу',
                      style: TextStyle(color: AppThemes.getTextColor(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
