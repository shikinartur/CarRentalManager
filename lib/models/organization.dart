import 'package:cloud_firestore/cloud_firestore.dart';

class Organization {
  final String id;
  final String name;
  final String directorUserId; // ID пользователя с ролью DIRECTOR
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Organization({
    required this.id,
    required this.name,
    required this.directorUserId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // Создать из Firestore документа
  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Organization(
      id: doc.id,
      name: data['name'] ?? '',
      directorUserId: data['director_user_id'] ?? '',
      isActive: data['is_active'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'director_user_id': directorUserId,
      'is_active': isActive,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Создать копию с изменениями
  Organization copyWith({
    String? name,
    String? directorUserId,
    bool? isActive,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      directorUserId: directorUserId ?? this.directorUserId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Генерировать уникальный ID организации (ORG_XXX)
  static String generateOrgId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ORG_$timestamp';
  }

  @override
  String toString() {
    return 'Organization(id: $id, name: $name, isActive: $isActive)';
  }
}