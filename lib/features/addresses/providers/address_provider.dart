import 'package:flutter/material.dart';
import '../models/address_model.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class AddressProvider extends ChangeNotifier {
  final List<AddressModel> _addresses = [];
  List<AddressModel> get addresses => List.unmodifiable(_addresses);

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  String? _defaultAddressId;
  String? get defaultAddressId => _defaultAddressId;

  AddressModel? get defaultAddress {
    if (_addresses.isEmpty) return null;

    if (_defaultAddressId != null) {
      try {
        return _addresses.firstWhere((a) => a.id == _defaultAddressId);
      } catch (e) {
        // If default address ID doesn't exist, return first address
        return _addresses.first;
      }
    }

    return _addresses.first;
  }

  AddressProvider() {
    _init();
  }

  void _init() {
    final user = _auth.currentUser;
    if (user == null) return;

    _sub = _db
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .snapshots()
        .listen((snap) {
      _addresses
        ..clear()
        ..addAll(snap.docs.map((d) {
          final data = d.data();
          return AddressModel(
            id: d.id,
            firstName: data['firstName'] ?? '',
            lastName: data['lastName'] ?? '',
            district: data['district'] ?? '',
            line1: data['line1'] ?? '',
            apartment: data['apartment'] ?? '',
            phone: data['phone'] ?? '',
            khoroo: (data['khoroo'] ?? 1) as int,
          );
        }));
      notifyListeners();
    });

    // listen to defaultAddressId field on user doc
    _userSub = _db.collection('users').doc(user.uid).snapshots().listen((snap) {
      _defaultAddressId = snap.data()?['defaultAddressId'] as String?;
      notifyListeners();
    });
  }

  Future<void> add(AddressModel addr) async {
    final user = _auth.currentUser;
    if (user == null) {
      _addresses.add(addr);
      notifyListeners();
      return;
    }
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .doc(addr.id)
        .set({
      'firstName': addr.firstName,
      'lastName': addr.lastName,
      'district': addr.district,
      'line1': addr.line1,
      'apartment': addr.apartment,
      'phone': addr.phone,
      'khoroo': addr.khoroo,
    });
  }

  Future<void> update(AddressModel addr) async {
    final user = _auth.currentUser;
    if (user == null) {
      final idx = _addresses.indexWhere((a) => a.id == addr.id);
      if (idx >= 0) {
        _addresses[idx] = addr;
        notifyListeners();
      }
      return;
    }
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .doc(addr.id)
        .update({
      'firstName': addr.firstName,
      'lastName': addr.lastName,
      'district': addr.district,
      'line1': addr.line1,
      'apartment': addr.apartment,
      'phone': addr.phone,
      'khoroo': addr.khoroo,
    });
  }

  Future<void> delete(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      _addresses.removeWhere((a) => a.id == id);
      notifyListeners();
      return;
    }
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .doc(id)
        .delete();
  }

  AddressModel generateEmpty() => AddressModel(
        id: const Uuid().v4(),
        firstName: '',
        lastName: '',
        district: '',
        line1: '',
        apartment: '',
        phone: '',
        khoroo: 1,
      );

  Future<void> setDefaultAddress(String id) async {
    _defaultAddressId = id;
    notifyListeners();
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'defaultAddressId': id,
      }, SetOptions(merge: true));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
