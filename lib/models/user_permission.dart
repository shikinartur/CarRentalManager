import 'package:cloud_firestore/cloud_firestore.dart';

/// Специальные права пользователя
/// 
/// Эти права выдаются дополнительно к роли.
/// Например, менеджер может получить право подтверждать заявки агентов.
enum PermissionType {
  approveBookingRequests('APPROVE_BOOKING_REQUESTS'), // Подтверждать заявки на бронирование
  manageTeam('MANAGE_TEAM'),                          // Управлять командой
  viewFinancials('VIEW_FINANCIALS');                  // Просматривать финансы

  const PermissionType(this.value);
  final String value;

  static PermissionType fromString(String value) {
    return PermissionType.values.firstWhere(
      (perm) => perm.value == value,
      orElse: () => throw Exception('Unknown permission: $value'),
    );
  }

  String get description {
    switch (this) {
      case PermissionType.approveBookingRequests:
        return 'Подтверждение заявок на бронирование';
      case PermissionType.manageTeam:
        return 'Управление командой';
      case PermissionType.viewFinancials:
        return 'Просмотр финансов';
    }
  }
}

/// Специальное право пользователя в контексте компании
class UserPermission {
  final String id;
  final String userId;
  final String? companyId;    // Контекст: компания
  final String? garageId;     // Контекст: гараж
  final PermissionType permissionType;
  final String grantedBy;     // Кто выдал право (директор)
  final DateTime grantedAt;
  final bool isActive;
  final DateTime? expiresAt;  // Опционально: когда истекает

  UserPermission({
    required this.id,
    required this.userId,
    this.companyId,
    this.garageId,
    required this.permissionType,
    required this.grantedBy,
    required this.grantedAt,
    this.isActive = true,
    this.expiresAt,
  }) : assert(
    companyId != null || garageId != null,
    'Either companyId or garageId must be provided'
  );

  /// Создать из Firestore документа
  factory UserPermission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserPermission(
      id: doc.id,
      userId: data['user_id'] ?? '',
      companyId: data['company_id'],
      garageId: data['garage_id'],
      permissionType: PermissionType.fromString(data['permission_type'] ?? ''),
      grantedBy: data['granted_by'] ?? '',
      grantedAt: (data['granted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['is_active'] ?? true,
      expiresAt: (data['expires_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      if (companyId != null) 'company_id': companyId,
      if (garageId != null) 'garage_id': garageId,
      'permission_type': permissionType.value,
      'granted_by': grantedBy,
      'granted_at': Timestamp.fromDate(grantedAt),
      'is_active': isActive,
      if (expiresAt != null) 'expires_at': Timestamp.fromDate(expiresAt!),
    };
  }

  /// Проверить, истекло ли право
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Проверить, активно ли право
  bool get isValid => isActive && !isExpired;

  /// Создать копию с изменениями
  UserPermission copyWith({
    bool? isActive,
    DateTime? expiresAt,
  }) {
    return UserPermission(
      id: id,
      userId: userId,
      companyId: companyId,
      garageId: garageId,
      permissionType: permissionType,
      grantedBy: grantedBy,
      grantedAt: grantedAt,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() {
    final context = companyId != null 
        ? 'company: $companyId' 
        : 'garage: $garageId';
    return 'UserPermission(user: $userId, $context, permission: ${permissionType.value}, active: $isActive)';
  }
}
