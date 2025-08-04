import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';
import 'package:avii/core/utils/validation_utils.dart';
import 'package:avii/core/constants/ub_location.dart';

const Color kPrimaryBlue = Color.fromARGB(255, 22, 14, 179);

class AddEditAddressPage extends StatefulWidget {
  final AddressModel? address;
  const AddEditAddressPage({super.key, this.address});

  @override
  State<AddEditAddressPage> createState() => _AddEditAddressPageState();
}

class _AddEditAddressPageState extends State<AddEditAddressPage> {
  final _formKey = GlobalKey<FormState>();
  late String firstName;
  late String lastName;
  late String district;
  late String line1;
  String apartment = '';
  late String phone;
  late int khoroo;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    firstName = a?.firstName ?? '';
    lastName = a?.lastName ?? '';
    district = a?.district ?? kUbDistricts.first;
    line1 = a?.line1 ?? '';
    apartment = a?.apartment ?? '';
    phone = a?.phone ?? '';

    // Ensure khoroo is valid for the selected district
    final availableKhoroos = kUbDistrictKhoroos[district];
    if (availableKhoroos != null) {
      if (a?.khoroo != null && availableKhoroos.contains(a!.khoroo)) {
        khoroo = a.khoroo;
      } else {
        khoroo = availableKhoroos.first;
      }
    } else {
      // Fallback to first district if current district is not found
      district = kUbDistricts.first;
      khoroo = kUbDistrictKhoroos[district]!.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF4285F4),
        title: const Text(
          'Хүргэлтийн хаягууд',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Хүргэлтийн хаяг оруулна уу',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _field('Овог', initial: firstName, onSaved: (v) => firstName = v),
              const SizedBox(height: 12),
              _field('Нэр', initial: lastName, onSaved: (v) => lastName = v),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: district,
                decoration: const InputDecoration(
                  labelText: 'Дүүрэг',
                  labelStyle: TextStyle(color: Color(0xFF4285F4)),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4285F4))),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4285F4))),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF4285F4), width: 2)),
                ),
                items: kUbDistricts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() {
                  district = v!;
                  // Reset khoroo to first available value for the new district
                  final availableKhoroos = kUbDistrictKhoroos[district];
                  if (availableKhoroos != null) {
                    khoroo = availableKhoroos.first;
                  } else {
                    // Fallback to first district if selected district is not found
                    district = kUbDistricts.first;
                    khoroo = kUbDistrictKhoroos[district]!.first;
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: khoroo,
                decoration: const InputDecoration(
                  labelText: 'Хороо',
                  labelStyle: TextStyle(color: Color(0xFF4285F4)),
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4285F4))),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4285F4))),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF4285F4), width: 2)),
                ),
                items: kUbDistrictKhoroos[district]!
                    .map((k) =>
                        DropdownMenuItem(value: k, child: Text('$k-р хороо')))
                    .toList(),
                onChanged: (v) => setState(() => khoroo = v!),
              ),
              const SizedBox(height: 12),
              _field('Гэрийн хаяг',
                  initial: apartment,
                  onSaved: (v) => apartment = v,
                  required: true),
              const SizedBox(height: 12),
              _field('Утасны дугаар',
                  initial: phone,
                  onSaved: (v) => phone = v,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4285F4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF4285F4), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Хүргэлтийн хаяг хадаглаx',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label,
      {required String initial,
      required void Function(String) onSaved,
      bool required = true,
      TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      initialValue: initial,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4285F4)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4285F4)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4285F4), width: 2),
        ),
      ),
      validator: required
          ? () {
              final lower = label.toLowerCase();
              if (lower.contains('утас') || lower.contains('phone')) {
                return ValidationUtils.validatePhoneNumber;
              } else if (lower.contains('овог') || lower.contains('нэр')) {
                return ValidationUtils.validateName;
              } else {
                return ValidationUtils.validateAddress;
              }
            }()
          : null,
      keyboardType: keyboard,
      onSaved: (v) => onSaved(v ?? ''),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final provider = Provider.of<AddressProvider>(context, listen: false);
    if (widget.address == null) {
      provider.add(AddressModel(
          id: provider.generateEmpty().id,
          firstName: firstName,
          lastName: lastName,
          district: district,
          khoroo: khoroo,
          line1: line1,
          apartment: apartment,
          phone: phone));
    } else {
      provider.update(AddressModel(
          id: widget.address!.id,
          firstName: firstName,
          lastName: lastName,
          district: district,
          khoroo: khoroo,
          line1: line1,
          apartment: apartment,
          phone: phone));
    }
    Navigator.pop(context);
  }
}
