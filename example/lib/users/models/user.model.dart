import 'package:example/users/models/hair.model.dart';
import 'package:example/users/models/address.model.dart';
import 'package:example/users/models/bank.model.dart';
import 'package:example/users/models/company.model.dart';
import 'package:example/users/models/crypto.model.dart';

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String maidenName;
  final int age;
  final String gender;
  final String email;
  final String phone;
  final String username;
  final String password;
  final String birthDate;
  final String image;
  final String bloodGroup;
  final double height;
  final double weight;
  final String eyeColor;
  final Hair hair;
  final String ip;
  final Address address;
  final String macAddress;
  final String university;
  final Bank bank;
  final Company company;
  final String ein;
  final String ssn;
  final String userAgent;
  final Crypto crypto;
  final String role;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.maidenName,
    required this.age,
    required this.gender,
    required this.email,
    required this.phone,
    required this.username,
    required this.password,
    required this.birthDate,
    required this.image,
    required this.bloodGroup,
    required this.height,
    required this.weight,
    required this.eyeColor,
    required this.hair,
    required this.ip,
    required this.address,
    required this.macAddress,
    required this.university,
    required this.bank,
    required this.company,
    required this.ein,
    required this.ssn,
    required this.userAgent,
    required this.crypto,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    maidenName: json['maidenName'] as String,
    age: json['age'] as int,
    gender: json['gender'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String,
    username: json['username'] as String,
    password: json['password'] as String,
    birthDate: json['birthDate'] as String,
    image: json['image'] as String,
    bloodGroup: json['bloodGroup'] as String,
    height: json['height'] as double,
    weight: json['weight'] as double,
    eyeColor: json['eyeColor'] as String,
    hair: Hair.fromJson(json['hair'] as Map<String, dynamic>),
    ip: json['ip'] as String,
    address: Address.fromJson(json['address'] as Map<String, dynamic>),
    macAddress: json['macAddress'] as String,
    university: json['university'] as String,
    bank: Bank.fromJson(json['bank'] as Map<String, dynamic>),
    company: Company.fromJson(json['company'] as Map<String, dynamic>),
    ein: json['ein'] as String,
    ssn: json['ssn'] as String,
    userAgent: json['userAgent'] as String,
    crypto: Crypto.fromJson(json['crypto'] as Map<String, dynamic>),
    role: json['role'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'maidenName': maidenName,
    'age': age,
    'gender': gender,
    'email': email,
    'phone': phone,
    'username': username,
    'password': password,
    'birthDate': birthDate,
    'image': image,
    'bloodGroup': bloodGroup,
    'height': height,
    'weight': weight,
    'eyeColor': eyeColor,
    'hair': hair.toJson(),
    'ip': ip,
    'address': address.toJson(),
    'macAddress': macAddress,
    'university': university,
    'bank': bank.toJson(),
    'company': company.toJson(),
    'ein': ein,
    'ssn': ssn,
    'userAgent': userAgent,
    'crypto': crypto.toJson(),
    'role': role,
  };
}
