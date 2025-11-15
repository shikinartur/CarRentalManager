import 'package:cloud_firestore/cloud_firestore.dart';

/// Контекстная роль пользователя
/// 
/// Роль зависит от контекста (компания/гараж), а не глобальная.
/// Один пользователь может иметь разные роли в разных контекстах:
/// - В своей компании: DIRECTOR
/// - В своем гараже: OWNER
/// - В другой компании: MANAGER (внешний партнер)
/// 
/// Иерархия: OWNER > DIRECTOR > MANAGER > AGENT > GUEST
enum RoleType {
  owner('OWNER'),       // Владелец гаража/компании
  director('DIRECTOR'), // Директор компании
  manager('MANAGER'),   // Менеджер - мгновенное бронирование (привязан к компании)
  agent('AGENT'),       // Агент - формирует заявки
  guest('GUEST');       // Гость - роль по умолчанию, только просмотр

  const RoleType(this.value);
  final String value;

  static RoleType fromString(String value) {
    return RoleType.values.firstWhere(
      (role) => role.value == value,
      orElse: () => RoleType.guest,
    );
  }

  /// Проверить, может ли эта роль управлять компанией
  bool get canManageCompany => this == RoleType.owner || this == RoleType.director;

  /// Проверить, может ли эта роль создавать мгновенные бронирования
  bool get canCreateInstantBooking => this == RoleType.owner || 
                                       this == RoleType.director || 
                                       this == RoleType.manager;

  /// Проверить, может ли эта роль создавать заявки на бронирование
  bool get canCreateBookingRequest => this == RoleType.owner || 
                                       this == RoleType.director || 
                                       this == RoleType.manager ||
                                       this == RoleType.agent;

  /// Проверить, может ли эта роль работать с клиентами
  bool get canManageClients => this == RoleType.owner || 
                                this == RoleType.director || 
                                this == RoleType.manager ||
                                this == RoleType.agent;

  /// Проверить, является ли роль владельцем
  bool get isOwner => this == RoleType.owner;

  /// Проверить, является ли роль агентом
  bool get isAgent => this == RoleType.agent;

  /// Проверить, является ли роль гостем
  bool get isGuest => this == RoleType.guest;

  /// Получить описание роли
  String get description {
    switch (this) {
      case RoleType.owner:
        return 'Владелец';
      case RoleType.director:
        return 'Директор';
      case RoleType.manager:
        return 'Менеджер';
      case RoleType.agent:
        return 'Агент';
      case RoleType.guest:
        return 'Гость';
    }
  }
}

/// Роль пользователя в конкретном контексте
class UserRole {
  final String id;
  final String userId;
  final String? companyId;    // Контекст: компания
  final String? garageId;     // Контекст: гараж
  final RoleType roleType;
  final String? grantedBy;    // Кто выдал роль (для не-owner ролей)
  final DateTime grantedAt;
  final bool isActive;

  UserRole({
    required this.id,
    required this.userId,
    this.companyId,
    this.garageId,
    required this.roleType,
    this.grantedBy,
    required this.grantedAt,
    this.isActive = true,
  }) : assert(
    roleType == RoleType.guest || companyId != null || garageId != null,
    'Either companyId or garageId must be provided (except for guest role)'
  );

  /// Создать из Firestore документа
  factory UserRole.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserRole(
      id: doc.id,
      userId: data['user_id'] ?? '',
      companyId: data['company_id'],
      garageId: data['garage_id'],
      roleType: RoleType.fromString(data['role_type'] ?? 'GUEST'),
      grantedBy: data['granted_by'],
      grantedAt: (data['granted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['is_active'] ?? true,
    );
  }

  /// Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      if (companyId != null) 'company_id': companyId,
      if (garageId != null) 'garage_id': garageId,
      'role_type': roleType.value,
      if (grantedBy != null) 'granted_by': grantedBy,
      'granted_at': Timestamp.fromDate(grantedAt),
      'is_active': isActive,
    };
  }

  /// Проверить, это роль в компании
  bool get isCompanyRole => companyId != null;

  /// Проверить, это роль в гараже
  bool get isGarageRole => garageId != null;

  /// Создать копию с изменениями
  UserRole copyWith({
    bool? isActive,
    RoleType? roleType,
  }) {
    return UserRole(
      id: id,
      userId: userId,
      companyId: companyId,
      garageId: garageId,
      roleType: roleType ?? this.roleType,
      grantedBy: grantedBy,
      grantedAt: grantedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    final context = companyId != null 
        ? 'company: $companyId' 
        : 'garage: $garageId';
    return 'UserRole(user: $userId, $context, role: ${roleType.value}, active: $isActive)';
  }
}
