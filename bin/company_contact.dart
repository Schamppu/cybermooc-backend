import 'dart:math';

import 'package:uuid/uuid.dart';

class CompanyContact {
  final String id;
  final String companyName;
  final String firstName;
  final String lastName;
  final String phone;

  const CompanyContact(
    this.id,
    this.companyName,
    this.firstName,
    this.lastName,
    this.phone,
  );

  factory CompanyContact.fromJson(Map<String, dynamic> json) {
    return CompanyContact(
      json['id'] != null ? json['id'] as String : Uuid().v4(),
      json['companyName'] != null ? json['companyName'] as String : 'null',
      json['firstName'] != null ? json['firstName'] as String : 'null',
      json['lastName'] != null ? json['lastName'] as String : 'null',
      json['phone'] != null ? json['phone'] as String : 'null',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyName': companyName,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
    };
  }
}
