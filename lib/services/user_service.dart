import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firestore_service.dart';

class UserService extends FirestoreService<AppUser> {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  @override
  CollectionReference get collection => 
      FirebaseFirestore.instance.collection('users');

  @override
  AppUser fromFirestore(DocumentSnapshot doc) => AppUser.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(AppUser user) => user.toFirestore();

  /// Получить пользователей организации
  Future<List<AppUser>> getUsersOfOrganization(String organizationId) async {
    try {
      final snapshot = await collection
          .where('organizations', arrayContains: organizationId)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения пользователей организации: $e');
    }
  }

  /// Получить пользователей с определенной глобальной ролью в организации
  Future<List<AppUser>> getUsersByGlobalRole(
    String organizationId, 
    GlobalRole role,
  ) async {
    try {
      // TODO: Переделать для контекстных ролей
      // Пока возвращаем пустой список
      return [];
      // final users = await getUsersOfOrganization(organizationId);
      // return users.where((user) => user.globalRole == role).toList();
    } catch (e) {
      throw Exception('Ошибка получения пользователей по роли: $e');
    }
  }

  /// Получить директоров в организации
  Future<List<AppUser>> getDirectorsOfOrganization(String organizationId) async {
    return getUsersByGlobalRole(organizationId, GlobalRole.director);
  }

  /// Получить менеджеров в организации
  Future<List<AppUser>> getManagersOfOrganization(String organizationId) async {
    return getUsersByGlobalRole(organizationId, GlobalRole.manager);
  }

  /// Получить инвесторов в организации
  Future<List<AppUser>> getInvestorsOfOrganization(String organizationId) async {
    return getUsersByGlobalRole(organizationId, GlobalRole.investor);
  }

  /// Получить владельцев в организации (устаревший метод, использует getInvestorsOfOrganization)
  @Deprecated('Use getInvestorsOfOrganization instead')
  Future<List<AppUser>> getOwnersOfOrganization(String organizationId) async {
    return getInvestorsOfOrganization(organizationId);
  }

  /// Добавить пользователя к организации
  Future<void> addUserToOrganization(String userId, String organizationId) async {
    try {
      final user = await getById(userId);
      if (user == null) {
        throw Exception('Пользователь не найден');
      }

      final updatedOrganizations = List<String>.from(user.organizations);
      if (!updatedOrganizations.contains(organizationId)) {
        updatedOrganizations.add(organizationId);
      }

      await updateFields(userId, {
        'organizations': updatedOrganizations,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Ошибка добавления пользователя к организации: $e');
    }
  }

  /// Удалить пользователя из организации
  Future<void> removeUserFromOrganization(String userId, String organizationId) async {
    try {
      final user = await getById(userId);
      if (user == null) {
        throw Exception('Пользователь не найден');
      }

      final updatedOrganizations = List<String>.from(user.organizations);
      updatedOrganizations.remove(organizationId);

      await updateFields(userId, {
        'organizations': updatedOrganizations,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Ошибка удаления пользователя из организации: $e');
    }
  }

  /// Изменить глобальную роль пользователя
  Future<void> changeUserGlobalRole(String userId, GlobalRole newRole) async {
    try {
      await updateFields(userId, {
        'global_role': newRole.value,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Ошибка изменения роли пользователя: $e');
    }
  }

  /// Получить пользователей по глобальной роли
  Future<List<AppUser>> getUsersByRole(GlobalRole role) async {
    try {
      final snapshot = await collection
          .where('global_role', isEqualTo: role.value)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения пользователей по глобальной роли: $e');
    }
  }

  /// Проверить доступ пользователя к организации
  Future<bool> hasAccessToOrganization(String userId, String organizationId) async {
    try {
      final user = await getById(userId);
      return user?.hasAccessToOrganization(organizationId) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Поиск пользователей по email
  Future<List<AppUser>> searchUsersByEmail(String searchTerm) async {
    try {
      // Firestore не поддерживает полнотекстовый поиск
      // Используем простой подход с фильтром по началу email
      final snapshot = await collection
          .where('email', isGreaterThanOrEqualTo: searchTerm.toLowerCase())
          .where('email', isLessThanOrEqualTo: '${searchTerm.toLowerCase()}\uf8ff')
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка поиска пользователей: $e');
    }
  }

  /// Получить статистику пользователя
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final user = await getById(userId);
      if (user == null) {
        throw Exception('Пользователь не найден');
      }

      return {
        'id': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        // 'global_role': user.globalRole.value, // TODO: удалить или заменить
        'organizations_count': user.organizations.length,
        'created_at': user.createdAt,
        'updated_at': user.updatedAt,
      };
    } catch (e) {
      throw Exception('Ошибка получения статистики пользователя: $e');
    }
  }

  /// Подписаться на изменения пользователей организации
  Stream<List<AppUser>> streamUsersOfOrganization(String organizationId) {
    return collection
        .where('organizations', arrayContains: organizationId)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  /// Подписаться на изменения конкретного пользователя
  Stream<AppUser?> streamUser(String userId) {
    return streamById(userId);
  }
}