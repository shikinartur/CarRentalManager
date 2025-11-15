import 'package:cloud_firestore/cloud_firestore.dart';

/// Права доступа к контактным данным клиента
/// 
/// Система прав:
/// - Создатель клиента имеет полный доступ
/// - Создатель может поделиться с любым пользователем (userId)
/// - Создатель может поделиться с компанией (companyId) - тогда доступ только у директора компании
/// 
/// Хранение: clients/{clientId}/permissions/{permissionId}
class ClientPermissions {
  final String id;
  final String clientId;
  final String? userId;      // Доступ для конкретного пользователя
  final String? companyId;   // Доступ для всей компании
  final DateTime grantedAt;
  final String grantedBy;    // ID пользователя, выдавшего доступ

  ClientPermissions({
    required this.id,
    required this.clientId,
    this.userId,
    this.companyId,
    required this.grantedAt,
    required this.grantedBy,
  }) : assert(userId != null || companyId != null, 
              'Either userId or companyId must be provided');

  /// Создать из Firestore документа
  factory ClientPermissions.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ClientPermissions(
      id: doc.id,
      clientId: data['client_id'] ?? '',
      userId: data['user_id'],
      companyId: data['company_id'],
      grantedAt: (data['granted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      grantedBy: data['granted_by'] ?? '',
    );
  }

  /// Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'client_id': clientId,
      if (userId != null) 'user_id': userId,
      if (companyId != null) 'company_id': companyId,
      'granted_at': Timestamp.fromDate(grantedAt),
      'granted_by': grantedBy,
    };
  }

  /// Проверить, это доступ для пользователя
  bool get isUserAccess => userId != null;

  /// Проверить, это доступ для компании
  bool get isCompanyAccess => companyId != null;

  @override
  String toString() {
    if (isUserAccess) {
      return 'ClientPermissions(client: $clientId, user: $userId)';
    } else {
      return 'ClientPermissions(client: $clientId, company: $companyId)';
    }
  }
}
