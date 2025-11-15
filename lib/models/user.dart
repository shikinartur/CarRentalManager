import 'package:cloud_firestore/cloud_firestore.dart';

enum GlobalRole {
  director('DIRECTOR'),  // Управляющий Автопарком
  manager('MANAGER'),    // Операционный Менеджер (Внутренний/Внешний)
  investor('INVESTOR'),  // Владелец-Инвестор (владеет автомобилями)
  guest('GUEST');        // Гость (ограниченный доступ для просмотра)

  const GlobalRole(this.value);
  final String value;

  static GlobalRole fromString(String value) {
    return GlobalRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => GlobalRole.guest,
    );
  }

  /// Проверить, может ли эта роль управлять автопарком
  bool get canManageFleet => this == GlobalRole.director;

  /// Проверить, может ли эта роль работать с бронированием
  bool get canManageBookings => this == GlobalRole.director || this == GlobalRole.manager;

  /// Проверить, является ли роль владельцем активов
  bool get isAssetOwner => this == GlobalRole.investor;

  /// Проверить, является ли роль гостевой (только просмотр)
  bool get isGuest => this == GlobalRole.guest;

  /// Получить описание роли
  String get description {
    switch (this) {
      case GlobalRole.director:
        return 'Управляющий Автопарком';
      case GlobalRole.manager:
        return 'Операционный Менеджер';
      case GlobalRole.investor:
        return 'Владелец-Инвестор';
      case GlobalRole.guest:
        return 'Гость';
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  // GlobalRole удалена - роль теперь контекстная (см. UserRole)
  final List<String> organizations; // Список org_id, к которым есть доступ
  final String? ownedCompanyId;     // ID компании, созданной пользователем (только одна)
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.organizations,
    this.ownedCompanyId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Проверить доступ к организации
  bool hasAccessToOrganization(String organizationId) {
    return organizations.contains(organizationId);
  }

  // Создать из Firestore документа
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['display_name'] ?? '',
      organizations: List<String>.from(data['organizations'] ?? []),
      ownedCompanyId: data['owned_company_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'display_name': displayName,
      'organizations': organizations,
      if (ownedCompanyId != null) 'owned_company_id': ownedCompanyId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Создать копию с изменениями
  AppUser copyWith({
    String? email,
    String? displayName,
    List<String>? organizations,
    String? ownedCompanyId,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      organizations: organizations ?? this.organizations,
      ownedCompanyId: ownedCompanyId ?? this.ownedCompanyId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AppUser(uid: $uid, email: $email, orgs: ${organizations.length})';
  }
}