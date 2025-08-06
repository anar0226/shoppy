import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../features/stores/models/store_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Payout settings
  MongolianBank? _selectedBank;
  final PayoutMethod _preferredPayoutMethod = PayoutMethod.bankTransfer;
  final PayoutFrequency _payoutFrequency = PayoutFrequency.weekly;
  final bool _autoPayoutEnabled = true;

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

  Future<void> _handleSave() async {
    // Validate all required fields
    if (!_formKey.currentState!.validate()) return;

    final contactError = _validateContactInfo();
    if (contactError != null) {
      setState(() => _error = contactError);
      return;
    }

    final payoutError = _validatePayoutInfo();
    if (payoutError != null) {
      setState(() => _error = payoutError);
      return;
    }

    // Save everything
    await _saveData();
  }

  Future<void> _saveData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Verify user authentication first
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please sign in again.');
      }

      // Force token refresh to ensure valid authentication
      await user.getIdToken(true);

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
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF4285F4),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.store,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Дэлгүүрийн анхны тохиргоо',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: _buildSinglePageForm(),
                  ),
                ),
              ),
            ),

            // Footer with buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
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
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Цуцлах'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _handleSave,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Дэлгүүр үүсгэх',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
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

  Widget _buildSinglePageForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Store Name Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Дэлгүүрийн нэр',
                Icons.store,
                'Дэлгүүрийн албан ёсны нэрийг оруулна уу',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storeNameCtrl,
                decoration: InputDecoration(
                  hintText: 'Жишээ: Anar Online Store',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4285F4), width: 2),
                  ),
                ),
                validator: (v) => v != null && v.trim().isNotEmpty
                    ? null
                    : 'Дэлгүүрийн нэр заавал оруулна уу',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Store Logo Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Дэлгүүрийн лого',
                Icons.image,
                'Таны дэлгүүрийн логог оруулна уу (сонголттой)',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  onTap: () async {
                    final picked = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (picked != null) {
                      setState(() => _logoFile = picked);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        size: 32,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Лого оруулахын тулд дарна уу',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PNG, JPG, JPEG (5МБ хүртэл)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_logoFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Сонгосон файл: ${_logoFile!.name}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Contact Information Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSectionHeader(
                      'Холбоо барих мэдээлэл',
                      Icons.phone,
                      'Хэрэглэгчид тантай холбогдох боломжтой дор хаяж нэг арга оруулна уу',
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Дор хаяж 1-ийг бөглөнө үү',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(
                        hintText: '99001234',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF4285F4), width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final phoneRegex = RegExp(r'^\d{8}$');
                          if (!phoneRegex.hasMatch(value.trim())) {
                            return 'Утасны дугаар 8 оронтой байх ёстой';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _instagramCtrl,
                      decoration: InputDecoration(
                        hintText: '@mystore',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF833AB4),
                                Color(0xFFFD1D1D),
                                Color(0xFFF77737),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF4285F4), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _facebookCtrl,
                      decoration: InputDecoration(
                        hintText: 'MyStore',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon:
                            const Icon(Icons.facebook, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF4285F4), width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 4. Bank Information Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Банкны мэдээлэл',
                Icons.account_balance,
                'Төлбөр хүлээж авахад ашиглах банкны дансны мэдээллээ оруулна уу',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MongolianBank>(
                value: _selectedBank,
                decoration: InputDecoration(
                  hintText: 'Банкаа сонгоно уу',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon:
                      const Icon(Icons.account_balance, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4285F4), width: 2),
                  ),
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bankAccountNumberCtrl,
                      decoration: InputDecoration(
                        hintText: '436022735',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF4285F4), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _bankAccountHolderNameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Дансны эзэмшигчийн нэр',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF4285F4), width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 5. ID Card Images Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Иргэний үнэмлэхний зураг',
                Icons.verified_user,
                'Баталгаажуулалтын зорилгоор иргэний үнэмлэхний урд ба арын талын зургийг оруулна уу',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _idCardFrontFile != null
                                ? Colors.green.shade400
                                : Colors.grey.shade300,
                            style: BorderStyle.solid,
                            width: _idCardFrontFile != null ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setState(() => _idCardFrontFile = picked);
                          }
                        },
                        child: _idCardFrontFile != null
                            ? Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green.shade600,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Урд тал',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _idCardFrontFile!.name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        TextButton(
                                          onPressed: () {
                                            setState(
                                                () => _idCardFrontFile = null);
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text(
                                            'Сонголтыг цуцлах',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Урд тал',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Icon(
                                    Icons.cloud_upload,
                                    size: 24,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Урд талын зураг оруулах',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'PNG, JPG (5МБ хүртэл)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _idCardBackFile != null
                                ? Colors.green.shade400
                                : Colors.grey.shade300,
                            style: BorderStyle.solid,
                            width: _idCardBackFile != null ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setState(() => _idCardBackFile = picked);
                          }
                        },
                        child: _idCardBackFile != null
                            ? Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green.shade600,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Ар тал',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _idCardBackFile!.name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        TextButton(
                                          onPressed: () {
                                            setState(
                                                () => _idCardBackFile = null);
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text(
                                            'Сонголтыг цуцлах',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Ар тал',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Icon(
                                    Icons.cloud_upload,
                                    size: 24,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Арын талын зураг оруулах',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'PNG, JPG (5МБ хүртэл)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4285F4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Color(0xFF4285F4), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Баталгаажуулалтын заавар',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                        '• Иргэний үнэмлэх тод, бүрэн харагдахаар зургийг авна уу'),
                    Text(
                        '• Зургийн чанар сайн, бичвэрүүд уншигдахуйц байх ёстой'),
                    Text('• Таны хувийн мэдээлэл аюулгүй хадгалагдана'),
                    Text(
                        '• Баталгаажуулалт дууссаны дараа зургийг устгах боломжтой'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 6. Return Policy Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Буцаалтын бодлого',
                Icons.description,
                'Таны дэлгүүрийн буцаалт, солилцооны бодлогыг тодорхой бичнэ үү',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _refundPolicyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Жишээ: 7 хоногийн дотор буцаах боломжтой. Барааны эх байдал хадгалагдсан байх ёстой. Хэрэглэгч тээврийн зардлыг хариуцна...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4285F4), width: 2),
                  ),
                ),
                validator: (v) => v != null && v.trim().isNotEmpty
                    ? null
                    : 'Буцаалтын бодлого заавал оруулна уу',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF4285F4), size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
