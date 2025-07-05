import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';
import 'package:avii/core/utils/validation_utils.dart';

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
  late String line1;
  String apartment = '';
  late String phone;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    firstName = a?.firstName ?? '';
    lastName = a?.lastName ?? '';
    line1 = a?.line1 ?? '';
    apartment = a?.apartment ?? '';
    phone = a?.phone ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.address != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Хүргэлтийн хаягууд'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Хүргэлтийн хаяг оруулна уу'),
              const SizedBox(height: 16),
              _field('Овог', initial: firstName, onSaved: (v) => firstName = v),
              const SizedBox(height: 12),
              _field('Нэр', initial: lastName, onSaved: (v) => lastName = v),
              const SizedBox(height: 12),
              _field('Xороо болон Дүүрэг',
                  initial: line1, onSaved: (v) => line1 = v),
              const SizedBox(height: 12),
              _field('Гэрийн хаяг',
                  initial: apartment,
                  onSaved: (v) => apartment = v,
                  required: false),
              const SizedBox(height: 12),
              _field('Утасны дугаар',
                  initial: phone,
                  onSaved: (v) => phone = v,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Хүргэлтийн хаяг хадаглаx'),
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
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required
          ? (label.toLowerCase().contains('phone')
              ? ValidationUtils.validatePhoneNumber
              : ValidationUtils.validateAddress)
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
          line1: line1,
          apartment: apartment,
          phone: phone));
    } else {
      provider.update(AddressModel(
          id: widget.address!.id,
          firstName: firstName,
          lastName: lastName,
          line1: line1,
          apartment: apartment,
          phone: phone));
    }
    Navigator.pop(context);
  }
}
