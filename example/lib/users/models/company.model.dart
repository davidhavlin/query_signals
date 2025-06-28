import 'package:example/users/models/address.model.dart';

class Company {
  final String department;
  final String name;
  final String title;
  final Address address;

  Company({
    required this.department,
    required this.name,
    required this.title,
    required this.address,
  });

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    department: json['department'] as String,
    name: json['name'] as String,
    title: json['title'] as String,
    address: Address.fromJson(json['address'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'department': department,
    'name': name,
    'title': title,
    'address': address.toJson(),
  };
}
