import 'package:flutter/material.dart';
import '../models/address_model.dart';
import 'package:uuid/uuid.dart';

class AddressProvider extends ChangeNotifier {
  final List<AddressModel> _addresses = [];
  List<AddressModel> get addresses => List.unmodifiable(_addresses);

  void add(AddressModel addr) {
    _addresses.add(addr);
    notifyListeners();
  }

  void update(AddressModel addr) {
    final idx = _addresses.indexWhere((a) => a.id == addr.id);
    if (idx >= 0) {
      _addresses[idx] = addr;
      notifyListeners();
    }
  }

  void delete(String id) {
    _addresses.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  AddressModel generateEmpty() => AddressModel(
        id: const Uuid().v4(),
        firstName: '',
        lastName: '',
        line1: '',
        apartment: '',
        phone: '',
      );
}
