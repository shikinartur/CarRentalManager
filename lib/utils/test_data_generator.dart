import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_role.dart';

/// Утилита для создания тестовых данных
/// 
/// Создает:
/// - 1 компанию с директором и менеджером
/// - 1 гараж с машинами в управлении компании
/// - 1 инвестора (владелец гаража)
/// - 1 агента
class TestDataGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // Тестовые пользователи
  static const Map<String, Map<String, String>> testUsers = {
    'director': {
      'email': 'director@test.com',
      'password': 'test123',
      'name': 'Иван Директоров',
    },
    'manager': {
      'email': 'manager@test.com',
      'password': 'test123',
      'name': 'Петр Менеджеров',
    },
    'investor': {
      'email': 'investor@test.com',
      'password': 'test123',
      'name': 'Сергей Инвесторов',
    },
    'agent': {
      'email': 'agent@test.com',
      'password': 'test123',
      'name': 'Алексей Агентов',
    },
  };

  /// Создать всю тестовую структуру
  Future<void> createTestData() async {
    print('🚀 Начало создания тестовых данных...');

    try {
      // 1. Создаем пользователей
      final directorUid = await _createUser('director');
      final managerUid = await _createUser('manager');
      final investorUid = await _createUser('investor');
      final agentUid = await _createUser('agent');

      print('✅ Пользователи созданы');

      // 2. Создаем компанию
      final companyId = await _createCompany(directorUid);
      print('✅ Компания создана: $companyId');

      // 3. Создаем гараж инвестора
      final garageId = await _createGarage(investorUid);
      print('✅ Гараж создан: $garageId');

      // 4. Назначаем роли
      await _assignRole(directorUid, companyId, null, RoleType.director);
      await _assignRole(managerUid, companyId, null, RoleType.manager);
      await _assignRole(investorUid, null, garageId, RoleType.owner);
      // Агент не имеет привязки к компании/гаражу
      print('✅ Роли назначены (агент: $agentUid без привязки)');

      // 5. Создаем машины в компании
      await _createCarsForCompany(companyId);
      print('✅ Машины компании созданы');

      // 6. Создаем машины в гараже (под управлением компании)
      await _createCarsInGarage(garageId, companyId, investorUid);
      print('✅ Машины гаража созданы');

      print('🎉 Тестовые данные успешно созданы!');
      print('');
      print('📋 Данные для входа:');
      print('Директор: ${testUsers['director']!['email']} / ${testUsers['director']!['password']}');
      print('Менеджер: ${testUsers['manager']!['email']} / ${testUsers['manager']!['password']}');
      print('Инвестор: ${testUsers['investor']!['email']} / ${testUsers['investor']!['password']}');
      print('Агент: ${testUsers['agent']!['email']} / ${testUsers['agent']!['password']}');
    } catch (e) {
      print('❌ Ошибка при создании тестовых данных: $e');
      rethrow;
    }
  }

  /// Создать пользователя
  Future<String> _createUser(String role) async {
    final userData = testUsers[role]!;
    
    try {
      // Проверяем, существует ли пользователь
      final methods = await _auth.fetchSignInMethodsForEmail(userData['email']!);
      
      if (methods.isNotEmpty) {
        // Пользователь существует, получаем его UID
        print('⚠️  Пользователь ${userData['email']} уже существует');
        final credential = await _auth.signInWithEmailAndPassword(
          email: userData['email']!,
          password: userData['password']!,
        );
        await _auth.signOut();
        return credential.user!.uid;
      }
    } catch (e) {
      // Продолжаем создание
    }

    // Создаем нового пользователя
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: userData['email']!,
      password: userData['password']!,
    );

    final uid = userCredential.user!.uid;

    // Обновляем профиль
    await userCredential.user!.updateDisplayName(userData['name']);

    // Создаем документ в Firestore
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': userData['email'],
      'display_name': userData['name'],
      'created_at': FieldValue.serverTimestamp(),
    });

    await _auth.signOut();
    return uid;
  }

  /// Создать компанию
  Future<String> _createCompany(String ownerId) async {
    final companyRef = _firestore.collection('organizations').doc();
    
    await companyRef.set({
      'id': companyRef.id,
      'name': 'Тестовая Прокатная Компания',
      'type': 'company',
      'owner_id': ownerId,
      'created_at': FieldValue.serverTimestamp(),
      'is_active': true,
      'description': 'Компания для тестирования системы',
      'contact_email': 'company@test.com',
      'contact_phone': '+7 (999) 123-45-67',
    });

    return companyRef.id;
  }

  /// Создать гараж
  Future<String> _createGarage(String ownerId) async {
    final garageRef = _firestore.collection('organizations').doc();
    
    await garageRef.set({
      'id': garageRef.id,
      'name': 'Гараж Инвестора',
      'type': 'garage',
      'owner_id': ownerId,
      'created_at': FieldValue.serverTimestamp(),
      'is_active': true,
      'description': 'Личный гараж с машинами под управлением компании',
    });

    return garageRef.id;
  }

  /// Назначить роль
  Future<void> _assignRole(
    String userId,
    String? companyId,
    String? garageId,
    RoleType roleType,
  ) async {
    final roleRef = _firestore.collection('user_roles').doc();
    
    await roleRef.set({
      'id': roleRef.id,
      'user_id': userId,
      'company_id': companyId,
      'garage_id': garageId,
      'role_type': roleType.value,
      'is_active': true,
      'granted_at': FieldValue.serverTimestamp(),
      'granted_by': userId, // В реальности это был бы другой пользователь
    });
  }

  /// Создать машины для компании
  Future<void> _createCarsForCompany(String companyId) async {
    final cars = [
      {
        'brand': 'Toyota',
        'model': 'Camry',
        'year': 2023,
        'color': 'Серый',
        'plate': 'А123БВ777',
        'vin': 'JT2BF18K8X0123456',
      },
      {
        'brand': 'Hyundai',
        'model': 'Solaris',
        'year': 2022,
        'color': 'Белый',
        'plate': 'К456МН177',
        'vin': 'Z94CB41AABR123456',
      },
    ];

    for (final carData in cars) {
      final carRef = _firestore.collection('cars').doc();
      
      await carRef.set({
        'id': carRef.id,
        'owner_id': companyId,
        'owner_type': 'company',
        'managed_by_company_id': companyId,
        'brand': carData['brand'],
        'model': carData['model'],
        'year': carData['year'],
        'color': carData['color'],
        'license_plate': carData['plate'],
        'vin': carData['vin'],
        'status': 'available',
        'daily_rate': 2500.0,
        'created_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });
    }
  }

  /// Создать машины в гараже
  Future<void> _createCarsInGarage(
    String garageId,
    String managedByCompanyId,
    String ownerId,
  ) async {
    final cars = [
      {
        'brand': 'BMW',
        'model': 'X5',
        'year': 2024,
        'color': 'Черный',
        'plate': 'В789ГД199',
        'vin': 'WBAFW71070L123456',
      },
      {
        'brand': 'Mercedes-Benz',
        'model': 'E-Class',
        'year': 2023,
        'color': 'Серебристый',
        'plate': 'М012НП777',
        'vin': 'WDD2130301A123456',
      },
    ];

    for (final carData in cars) {
      final carRef = _firestore.collection('cars').doc();
      
      await carRef.set({
        'id': carRef.id,
        'owner_id': ownerId,
        'owner_type': 'user',
        'garage_id': garageId,
        'managed_by_company_id': managedByCompanyId,
        'brand': carData['brand'],
        'model': carData['model'],
        'year': carData['year'],
        'color': carData['color'],
        'license_plate': carData['plate'],
        'vin': carData['vin'],
        'status': 'available',
        'daily_rate': 5000.0,
        'created_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });
    }
  }

  /// Очистить все тестовые данные
  Future<void> clearTestData() async {
    print('🧹 Очистка тестовых данных...');

    try {
      // Удаляем пользователей
      for (final role in testUsers.keys) {
        try {
          final userData = testUsers[role]!;
          final credential = await _auth.signInWithEmailAndPassword(
            email: userData['email']!,
            password: userData['password']!,
          );
          
          final uid = credential.user!.uid;
          
          // Удаляем роли
          final roles = await _firestore
              .collection('user_roles')
              .where('user_id', isEqualTo: uid)
              .get();
          for (final doc in roles.docs) {
            await doc.reference.delete();
          }
          
          // Удаляем документ пользователя
          await _firestore.collection('users').doc(uid).delete();
          
          // Удаляем аккаунт
          await credential.user!.delete();
          
          print('✅ Удален: ${userData['email']}');
        } catch (e) {
          print('⚠️  Ошибка при удалении пользователя: $e');
        }
      }

      // Удаляем организации (с префиксом "Тест")
      final orgs = await _firestore
          .collection('organizations')
          .where('name', isGreaterThanOrEqualTo: 'Тест')
          .where('name', isLessThan: 'Тесу')
          .get();
      for (final doc in orgs.docs) {
        await doc.reference.delete();
      }

      // Удаляем машины тестовых организаций
      final cars = await _firestore.collection('cars').get();
      for (final doc in cars.docs) {
        final data = doc.data();
        if (data['license_plate']?.toString().contains(RegExp(r'[АВК123456789МНП]')) == true) {
          await doc.reference.delete();
        }
      }

      print('✅ Тестовые данные очищены');
    } catch (e) {
      print('❌ Ошибка при очистке: $e');
    } finally {
      await _auth.signOut();
    }
  }
}
