import 'package:cloud_firestore/cloud_firestore.dart';

/// Делегирование прав директора менеджеру
/// 
/// Директор может передать менеджеру все свои права роли DIRECTOR,
/// кроме права закрытия компании.
/// 
/// Делегированные права:
/// - Управление автомобилями компании (добавление, редактирование, удаление)
/// - Выдача прав доступа к автомобилям другим менеджерам
/// - Управление контактами компании и предоставление доступа к ним
/// - Просмотр всех аренд компании
/// - Финансовая отчетность компании
/// 
/// НЕ делегируется:
/// - Закрытие компании (только сам директор)
/// 
/// Хранение: companies/{companyId}/director_delegations/{userId}
class DirectorDelegation {
  final String id;
  final String companyId;
  final String userId;        // ID менеджера, получившего права
  final DateTime grantedAt;
  final String grantedBy;     // ID директора, выдавшего права
  final bool isActive;        // Активна ли делегация

  DirectorDelegation({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.grantedAt,
    required this.grantedBy,
    this.isActive = true,
  });

  /// Создать из Firestore документа
  factory DirectorDelegation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return DirectorDelegation(
      id: doc.id,
      companyId: data['company_id'] ?? '',
      userId: data['user_id'] ?? '',
      grantedAt: (data['granted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      grantedBy: data['granted_by'] ?? '',
      isActive: data['is_active'] ?? true,
    );
  }

  /// Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'company_id': companyId,
      'user_id': userId,
      'granted_at': Timestamp.fromDate(grantedAt),
      'granted_by': grantedBy,
      'is_active': isActive,
    };
  }

  /// Создать копию с изменениями
  DirectorDelegation copyWith({
    bool? isActive,
  }) {
    return DirectorDelegation(
      id: id,
      companyId: companyId,
      userId: userId,
      grantedAt: grantedAt,
      grantedBy: grantedBy,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'DirectorDelegation(company: $companyId, user: $userId, active: $isActive)';
  }
}
