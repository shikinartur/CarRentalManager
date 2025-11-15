import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String? driverLicenseInfo; // Информация о водительских правах (для OCR)
  final String? passportInfo; // Информация о паспорте (для OCR)
  final String createdBy; // ID пользователя, создавшего клиента
  final DateTime createdAt;
  final DateTime updatedAt;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.driverLicenseInfo,
    this.passportInfo,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // Проверить, заполнены ли основные поля
  bool get hasBasicInfo => name.isNotEmpty && phone.isNotEmpty;

  // Проверить, заполнены ли документы
  bool get hasDocuments => driverLicenseInfo != null && passportInfo != null;

  // Проверить валидность email
  bool get hasValidEmail {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  // Создать из Firestore документа
  factory Client.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Client(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      driverLicenseInfo: data['driver_license_info'],
      passportInfo: data['passport_info'],
      createdBy: data['created_by'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      if (driverLicenseInfo != null) 'driver_license_info': driverLicenseInfo,
      if (passportInfo != null) 'passport_info': passportInfo,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Создать копию с изменениями
  Client copyWith({
    String? name,
    String? phone,
    String? email,
    String? driverLicenseInfo,
    String? passportInfo,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      driverLicenseInfo: driverLicenseInfo ?? this.driverLicenseInfo,
      passportInfo: passportInfo ?? this.passportInfo,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Client(id: $id, name: $name, phone: $phone)';
  }
}