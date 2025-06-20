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

  String formatted() {
    final buffer = StringBuffer()
      ..write('$firstName $lastName, ')
      ..write(line1);
    if (apartment.isNotEmpty) buffer.write(' $apartment');
    buffer.write(', $phone');
    return buffer.toString();
  }
}
