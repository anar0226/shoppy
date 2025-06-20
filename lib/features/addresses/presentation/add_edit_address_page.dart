import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';

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
        title: const Text('Shipping Address'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                  'Please enter the address that you want your product to get delivered to'),
              const SizedBox(height: 16),
              _field('First name',
                  initial: firstName, onSaved: (v) => firstName = v),
              const SizedBox(height: 12),
              _field('Last name',
                  initial: lastName, onSaved: (v) => lastName = v),
              const SizedBox(height: 12),
              _field('Address', initial: line1, onSaved: (v) => line1 = v),
              const SizedBox(height: 12),
              _field('Apartment, Suite, etc',
                  initial: apartment,
                  onSaved: (v) => apartment = v,
                  required: false),
              const SizedBox(height: 12),
              _field('Phone number',
                  initial: phone,
                  onSaved: (v) => phone = v,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Save address'),
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
      validator:
          required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
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
