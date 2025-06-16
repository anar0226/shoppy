class AddressModel {
  final String id;
  String firstName;
  String lastName;
  String line1;
  String apartment;
  String phone;

  AddressModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.line1,
    this.apartment = '',
    required this.phone,
  });
}
