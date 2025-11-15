import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user.dart';
import '../models/user_role.dart';

/// Сервис для управления тестовыми пользователями
class TestUserService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Получить всех тестовых пользователей
  Stream<List<UserWithRoles>> getAllTestUsers() {
    return _firestore
        .collection('users')
        .where('isTestUser', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<UserWithRoles> usersWithRoles = [];
      
      for (var doc in snapshot.docs) {
        final user = AppUser.fromFirestore(doc);
        final data = doc.data();
        final testPassword = data['testPassword'] as String?;
        
        // Получить роли пользователя
        final rolesSnapshot = await _firestore
            .collection('user_roles')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();
        
        final roles = rolesSnapshot.docs
            .map((roleDoc) => UserRole.fromFirestore(roleDoc))
            .toList();
        
        // Получить информацию о связях
        Map<String, String> companyNames = {};
        Map<String, String> garageNames = {};
        Map<String, String> managerNames = {};
        Map<String, String> directorNames = {};
        Map<String, String> agentNames = {};
        Map<String, String> investorNames = {};
        Map<String, String> partnerNames = {};
        
        // Загрузить названия компаний
        for (var role in roles) {
          if (role.companyId != null && !companyNames.containsKey(role.companyId)) {
            final companyDoc = await _firestore.collection('companies').doc(role.companyId).get();
            if (companyDoc.exists) {
              companyNames[role.companyId!] = companyDoc.data()?['name'] ?? 'Без названия';
            }
          }
          
          // Загрузить названия гаражей
          if (role.garageId != null && !garageNames.containsKey(role.garageId)) {
            final garageDoc = await _firestore.collection('garages').doc(role.garageId).get();
            if (garageDoc.exists) {
              garageNames[role.garageId!] = garageDoc.data()?['name'] ?? 'Без названия';
            }
          }
        }
        
        // Получить связанных пользователей (менеджеров, директоров, агентов, инвесторов)
        // TODO: Это нужно реализовать через соответствующие коллекции связей
        
        usersWithRoles.add(UserWithRoles(
          user: user, 
          roles: roles,
          testPassword: testPassword,
          companyNames: companyNames,
          garageNames: garageNames,
          managerNames: managerNames,
          directorNames: directorNames,
          agentNames: agentNames,
          investorNames: investorNames,
          partnerNames: partnerNames,
        ));
      }
      
      return usersWithRoles;
    });
  }

  /// Создать нового тестового пользователя
  Future<String> createTestUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // Создать пользователя в Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;

      // Создать документ пользователя в Firestore
      final user = AppUser(
        uid: userId,
        email: email,
        displayName: displayName,
        organizations: [],
        ownedCompanyId: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Добавить флаг isTestUser и пароль в Firestore (только для тестовых пользователей!)
      final userData = user.toFirestore();
      userData['isTestUser'] = true;
      userData['testPassword'] = password; // Сохраняем пароль только для тестовых пользователей
      
      await _firestore.collection('users').doc(userId).set(userData);

      // Создать роль GUEST по умолчанию
      final guestRole = UserRole(
        id: _firestore.collection('user_roles').doc().id,
        userId: userId,
        companyId: null,
        garageId: null,
        roleType: RoleType.guest,
        grantedBy: null,
        grantedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection('user_roles')
          .doc(guestRole.id)
          .set(guestRole.toFirestore());

      return userId;
    } catch (e) {
      throw Exception('Ошибка создания пользователя: $e');
    }
  }

  /// Удалить тестового пользователя
  /// Примечание: удаляет из Firestore, но НЕ из Firebase Auth
  /// Email останется занятым в системе аутентификации
  Future<void> deleteTestUser(String userId) async {
    try {
      // Удалить все роли пользователя
      final rolesSnapshot = await _firestore
          .collection('user_roles')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in rolesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Удалить документ пользователя
      await _firestore.collection('users').doc(userId).delete();

      // Примечание: Firebase Auth не позволяет удалять пользователей программно
      // без использования Firebase Admin SDK или Cloud Functions
      // Email останется занятым в системе аутентификации
    } catch (e) {
      throw Exception('Ошибка удаления пользователя: $e');
    }
  }

  /// Удалить всех тестовых пользователей
  /// Примечание: удаляет из Firestore, но НЕ из Firebase Auth
  Future<void> deleteAllTestUsers() async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('isTestUser', isEqualTo: true)
          .get();
      
      for (var userDoc in usersSnapshot.docs) {
        await deleteTestUser(userDoc.id);
      }
    } catch (e) {
      throw Exception('Ошибка удаления всех пользователей: $e');
    }
  }

  /// Быстрый вход под тестовым пользователем
  Future<void> quickLogin({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Ошибка входа: $e');
    }
  }

  /// Назначить роль пользователю
  Future<void> assignRole({
    required String userId,
    required RoleType roleType,
    String? companyId,
    String? garageId,
    required String grantedBy,
  }) async {
    try {
      final roleId = _firestore.collection('user_roles').doc().id;
      
      final role = UserRole(
        id: roleId,
        userId: userId,
        companyId: companyId,
        garageId: garageId,
        roleType: roleType,
        grantedBy: grantedBy,
        grantedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection('user_roles')
          .doc(roleId)
          .set(role.toFirestore());
    } catch (e) {
      throw Exception('Ошибка назначения роли: $e');
    }
  }

  /// Удалить роль пользователя
  Future<void> removeRole(String roleId) async {
    try {
      await _firestore.collection('user_roles').doc(roleId).delete();
    } catch (e) {
      throw Exception('Ошибка удаления роли: $e');
    }
  }
}

/// Модель пользователя с ролями для удобства
class UserWithRoles {
  final AppUser user;
  final List<UserRole> roles;
  final String? testPassword; // Пароль для тестовых пользователей
  final Map<String, String> companyNames; // companyId -> название компании
  final Map<String, String> garageNames; // garageId -> название гаража
  final Map<String, String> managerNames; // userId -> имя менеджера
  final Map<String, String> directorNames; // userId -> имя директора
  final Map<String, String> agentNames; // userId -> имя агента
  final Map<String, String> investorNames; // userId -> имя инвестора
  final Map<String, String> partnerNames; // companyId -> название компании-партнера

  UserWithRoles({
    required this.user,
    required this.roles,
    this.testPassword,
    this.companyNames = const {},
    this.garageNames = const {},
    this.managerNames = const {},
    this.directorNames = const {},
    this.agentNames = const {},
    this.investorNames = const {},
    this.partnerNames = const {},
  });

  /// Получить основную роль (с самым высоким приоритетом)
  RoleType get primaryRole {
    if (roles.isEmpty) return RoleType.guest;
    
    // Приоритет: owner > director > manager > agent > guest
    if (roles.any((r) => r.roleType == RoleType.owner)) return RoleType.owner;
    if (roles.any((r) => r.roleType == RoleType.director)) return RoleType.director;
    if (roles.any((r) => r.roleType == RoleType.manager)) return RoleType.manager;
    if (roles.any((r) => r.roleType == RoleType.agent)) return RoleType.agent;
    return RoleType.guest;
  }

  /// Получить описание всех ролей
  String get rolesDescription {
    if (roles.isEmpty) return 'Гость';
    return roles.map((r) => r.roleType.description).join(', ');
  }
  
  /// Получить компанию пользователя (если есть роль владельца)
  String? get ownedCompany {
    if (roles.isEmpty) return null;
    
    try {
      final ownerRole = roles.firstWhere(
        (r) => r.roleType == RoleType.owner,
      );
      return ownerRole.companyId != null ? companyNames[ownerRole.companyId] : null;
    } catch (e) {
      // Нет роли владельца, проверим другие роли с companyId
      for (var role in roles) {
        if (role.companyId != null) {
          return companyNames[role.companyId];
        }
      }
      return null;
    }
  }
  
  /// Получить гараж пользователя
  String? get primaryGarage {
    if (roles.isEmpty) return null;
    
    try {
      final roleWithGarage = roles.firstWhere(
        (r) => r.garageId != null,
      );
      return roleWithGarage.garageId != null ? garageNames[roleWithGarage.garageId] : null;
    } catch (e) {
      return null;
    }
  }
}
