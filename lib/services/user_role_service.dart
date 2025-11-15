import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role.dart';

/// Сервис для работы с контекстными ролями пользователей
/// 
/// Управляет ролями пользователей в разных контекстах (компании, гаражи).
/// Один пользователь может иметь разные роли в разных контекстах.
class UserRoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========================================
  // ПОЛУЧЕНИЕ РОЛЕЙ
  // ========================================

  /// Получить роль пользователя в компании
  Future<RoleType> getUserRoleInCompany(String userId, String companyId) async {
    try {
      final roleSnapshot = await _firestore
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .where('company_id', isEqualTo: companyId)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (roleSnapshot.docs.isEmpty) return RoleType.agent;

      final role = UserRole.fromFirestore(roleSnapshot.docs.first);
      return role.roleType;
    } catch (e) {
      print('Error getting user role in company: $e');
      return RoleType.agent;
    }
  }

  /// Получить роль пользователя в гараже
  Future<RoleType> getUserRoleInGarage(String userId, String garageId) async {
    try {
      final roleSnapshot = await _firestore
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .where('garage_id', isEqualTo: garageId)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (roleSnapshot.docs.isEmpty) return RoleType.agent;

      final role = UserRole.fromFirestore(roleSnapshot.docs.first);
      return role.roleType;
    } catch (e) {
      print('Error getting user role in garage: $e');
      return RoleType.agent;
    }
  }

  /// Получить все роли пользователя
  Future<List<UserRole>> getUserRoles(String userId) async {
    try {
      final rolesSnapshot = await _firestore
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .where('is_active', isEqualTo: true)
          .get();

      return rolesSnapshot.docs
          .map((doc) => UserRole.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting user roles: $e');
      return [];
    }
  }

  /// Получить все компании, где пользователь имеет роль
  Future<List<String>> getUserCompanies(String userId) async {
    try {
      final roles = await getUserRoles(userId);
      return roles
          .where((role) => role.companyId != null)
          .map((role) => role.companyId!)
          .toSet()
          .toList();
    } catch (e) {
      print('Error getting user companies: $e');
      return [];
    }
  }

  /// Получить все гаражи, где пользователь имеет роль
  Future<List<String>> getUserGarages(String userId) async {
    try {
      final roles = await getUserRoles(userId);
      return roles
          .where((role) => role.garageId != null)
          .map((role) => role.garageId!)
          .toSet()
          .toList();
    } catch (e) {
      print('Error getting user garages: $e');
      return [];
    }
  }

  // ========================================
  // СОЗДАНИЕ И НАЗНАЧЕНИЕ РОЛЕЙ
  // ========================================

  /// Создать роль владельца гаража (автоматически при создании гаража)
  Future<bool> createGarageOwnerRole({
    required String userId,
    required String garageId,
  }) async {
    try {
      await _firestore.collection('user_roles').add({
        'user_id': userId,
        'garage_id': garageId,
        'role_type': RoleType.owner.value,
        'granted_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });
      return true;
    } catch (e) {
      print('Error creating garage owner role: $e');
      return false;
    }
  }

  /// Создать роль владельца/директора компании (автоматически при создании компании)
  Future<bool> createCompanyOwnerRole({
    required String userId,
    required String companyId,
  }) async {
    try {
      await _firestore.collection('user_roles').add({
        'user_id': userId,
        'company_id': companyId,
        'role_type': RoleType.owner.value,
        'granted_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });
      return true;
    } catch (e) {
      print('Error creating company owner role: $e');
      return false;
    }
  }

  /// Назначить пользователю роль в компании
  Future<bool> assignCompanyRole({
    required String userId,
    required String companyId,
    required RoleType roleType,
    required String grantedBy,
  }) async {
    try {
      // Проверить, нет ли уже активной роли
      final existingRole = await _firestore
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .where('company_id', isEqualTo: companyId)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (existingRole.docs.isNotEmpty) {
        // Обновить существующую роль
        await existingRole.docs.first.reference.update({
          'role_type': roleType.value,
          'granted_by': grantedBy,
          'granted_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Создать новую роль
        await _firestore.collection('user_roles').add({
          'user_id': userId,
          'company_id': companyId,
          'role_type': roleType.value,
          'granted_by': grantedBy,
          'granted_at': FieldValue.serverTimestamp(),
          'is_active': true,
        });
      }
      return true;
    } catch (e) {
      print('Error assigning company role: $e');
      return false;
    }
  }

  /// Назначить пользователю роль в гараже
  Future<bool> assignGarageRole({
    required String userId,
    required String garageId,
    required RoleType roleType,
    required String grantedBy,
  }) async {
    try {
      // Проверить, нет ли уже активной роли
      final existingRole = await _firestore
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .where('garage_id', isEqualTo: garageId)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (existingRole.docs.isNotEmpty) {
        // Обновить существующую роль
        await existingRole.docs.first.reference.update({
          'role_type': roleType.value,
          'granted_by': grantedBy,
          'granted_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Создать новую роль
        await _firestore.collection('user_roles').add({
          'user_id': userId,
          'garage_id': garageId,
          'role_type': roleType.value,
          'granted_by': grantedBy,
          'granted_at': FieldValue.serverTimestamp(),
          'is_active': true,
        });
      }
      return true;
    } catch (e) {
      print('Error assigning garage role: $e');
      return false;
    }
  }

  // ========================================
  // УДАЛЕНИЕ И ДЕАКТИВАЦИЯ РОЛЕЙ
  // ========================================

  /// Деактивировать роль пользователя в компании
  Future<bool> revokeCompanyRole({
    required String userId,
    required String companyId,
  }) async {
    try {
      final roleSnapshot = await _firestore
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .where('company_id', isEqualTo: companyId)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (roleSnapshot.docs.isNotEmpty) {
        await roleSnapshot.docs.first.reference.update({'is_active': false});
      }
      return true;
    } catch (e) {
      print('Error revoking company role: $e');
      return false;
    }
  }

  /// Деактивировать роль пользователя в гараже
  Future<bool> revokeGarageRole({
    required String userId,
    required String garageId,
  }) async {
    try {
      final roleSnapshot = await _firestore
          .collection('user_roles')
          .where('user_id', isEqualTo: userId)
          .where('garage_id', isEqualTo: garageId)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();

      if (roleSnapshot.docs.isNotEmpty) {
        await roleSnapshot.docs.first.reference.update({'is_active': false});
      }
      return true;
    } catch (e) {
      print('Error revoking garage role: $e');
      return false;
    }
  }

  // ========================================
  // ПРОВЕРКИ ПРАВ
  // ========================================

  /// Проверить, является ли пользователь владельцем компании
  Future<bool> isCompanyOwner(String userId, String companyId) async {
    final role = await getUserRoleInCompany(userId, companyId);
    return role == RoleType.owner;
  }

  /// Проверить, является ли пользователь директором компании
  Future<bool> isCompanyDirector(String userId, String companyId) async {
    final role = await getUserRoleInCompany(userId, companyId);
    return role == RoleType.owner || role == RoleType.director;
  }

  /// Проверить, является ли пользователь менеджером компании
  Future<bool> isCompanyManager(String userId, String companyId) async {
    final role = await getUserRoleInCompany(userId, companyId);
    return role == RoleType.owner || 
           role == RoleType.director || 
           role == RoleType.manager;
  }

  /// Проверить, является ли пользователь владельцем гаража
  Future<bool> isGarageOwner(String userId, String garageId) async {
    final role = await getUserRoleInGarage(userId, garageId);
    return role == RoleType.owner;
  }
}
