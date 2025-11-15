import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/car.dart';
import '../models/car_permissions.dart';
import '../models/garage.dart';
import '../models/rental.dart';

/// Централизованный класс для проверки прав доступа в системе
/// Реализует логику "один актив — два субъекта ответственности"
/// 
/// Основные правила делегирования прав (car_permissions):
/// 1. canView (просмотр загрузки) - может выдать владелец гаража/компании любому пользователю
/// 2. Операционные права - может выдать только DIRECTOR компании
/// 3. Для выдачи операционных прав автомобиль должен быть передан в управление компании (companyId != null)
/// 
/// Типы прав (car_permissions):
/// - canView: просмотр загрузки автомобиля (может выдать владелец гаража/компании)
/// - canEditCar: редактирование данных автомобиля, НЕ включает удаление (только DIRECTOR)
/// - canBook: создание бронирований без подтверждения (только DIRECTOR)
/// - canOrder: создание заявок, требующих подтверждения (только DIRECTOR)
/// - canConfirm: подтверждение заявок других пользователей (только DIRECTOR)
/// - canHandover: выдача и приемка автомобиля - начало и завершение аренды (только DIRECTOR)
/// 
/// Редактирование своих заявок/броней:
/// - Менеджеры могут редактировать СВОИ заявки и бронирования
/// - canConfirm требуется для редактирования ЧУЖИХ заявок/броней
/// 
/// Добавление и удаление автомобилей:
/// - Владелец гаража может добавлять/удалять авто в своем гараже
/// - DIRECTOR может добавлять/удалять авто в компании
/// - canEditCar НЕ дает право удалять автомобили
/// 
/// Роли:
/// - Менеджеры (MANAGER) отличаются только набором прав на конкретные автомобили
/// - Нет понятия "менеджер компании" - есть только менеджеры с разными правами
/// 
/// Пример сценария 1 (просмотр календаря):
/// 1. Инвестор создает PersonalGarage с авто
/// 2. Инвестор выдает право canView любому пользователю для просмотра календаря
/// 
/// Пример сценария 2 (операционные права):
/// 1. Инвестор создает PersonalGarage с авто
/// 2. Инвестор передает авто под управление компании (устанавливает companyId)
/// 3. Теперь DIRECTOR этой компании может выдать операционные права MANAGER
class AccessControl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========================================
  // ПРОВЕРКИ ДОСТУПА К АВТОМОБИЛЯМ
  // ========================================

  /// Проверить, может ли пользователь просматривать автомобиль
  /// 
  /// Пользователь может просматривать авто если:
  /// 1. Он является владельцем гаража, в котором находится авто
  /// 2. Он является DIRECTOR компании, которая управляет авто
  /// 3. У него есть явное разрешение car_permissions с canView = true
  Future<bool> canViewCar(String userId, Car car, GlobalRole userRole) async {
    // 1. Владелец гаража может просматривать все авто в своем гараже
    final isGarageOwner = await _isOwnerOfGarage(userId, car.garageId);
    if (isGarageOwner) return true;

    // 2. Директор управляющей компании может просматривать все авто компании
    if (userRole == GlobalRole.director && car.companyId != null) {
      final isDirector = await _isDirectorOfCompany(userId, car.companyId!);
      if (isDirector) return true;
    }

    // 3. Проверить явные гранулярные права доступа (car_permissions)
    final hasPermission = await _hasCarPermission(userId, car.id, (perm) => perm.canView);
    return hasPermission;
  }

  /// Проверить, может ли пользователь редактировать автомобиль
  /// 
  /// Примечание: это право НЕ включает:
  /// - Удаление автомобиля
  /// - Изменение статуса доступности (вычисляется автоматически)
  /// 
  /// Можно редактировать: марку, модель, год, характеристики, фото, описание, тарифы
  Future<bool> canEditCar(String userId, Car car, GlobalRole userRole) async {
    // Владелец гаража может редактировать авто в своем гараже
    final isGarageOwner = await _isOwnerOfGarage(userId, car.garageId);
    if (isGarageOwner) return true;

    // Директор управляющей компании может редактировать
    if (userRole == GlobalRole.director && car.companyId != null) {
      final isDirector = await _isDirectorOfCompany(userId, car.companyId!);
      if (isDirector) return true;
    }

    // Менеджер может редактировать только с правами
    if (userRole == GlobalRole.manager) {
      return await _hasCarPermission(userId, car.id, (perm) => perm.canEditCar);
    }

    return false;
  }

  /// Проверить, может ли пользователь удалить автомобиль
  /// Удаление доступно только владельцу гаража или DIRECTOR компании
  Future<bool> canDeleteCar(String userId, Car car, GlobalRole userRole) async {
    // Владелец гаража может удалять авто из своего гаража
    final isGarageOwner = await _isOwnerOfGarage(userId, car.garageId);
    if (isGarageOwner) return true;

    // Директор управляющей компании может удалять авто компании
    if (userRole == GlobalRole.director && car.garageType == GarageType.company) {
      if (car.companyId != null) {
        return await _isDirectorOfCompany(userId, car.companyId!);
      }
    }

    return false;
  }

  /// Проверить, может ли пользователь передать автомобиль другой компании/гаражу
  Future<bool> canTransferCar(String userId, Car car) async {
    // Только владелец гаража может передавать авто
    return await _isOwnerOfGarage(userId, car.garageId);
  }

  // ========================================
  // ПРОВЕРКИ ДОСТУПА К БРОНИРОВАНИЮ
  // ========================================

  /// Проверить, может ли пользователь создать бронирование на автомобиль
  Future<bool> canCreateBooking(String userId, Car car, GlobalRole userRole) async {
    // Директор управляющей компании может бронировать
    if (userRole == GlobalRole.director && car.companyId != null) {
      final isDirector = await _isDirectorOfCompany(userId, car.companyId!);
      if (isDirector) return true;
    }

    // Менеджер может бронировать только с правами
    if (userRole == GlobalRole.manager) {
      return await _hasCarPermission(userId, car.id, (perm) => perm.canBook);
    }

    return false;
  }

  /// Проверить, может ли пользователь создавать заявки (orders)
  Future<bool> canCreateOrder(String userId, Car car, GlobalRole userRole) async {
    // Директор управляющей компании может создавать заявки
    if (userRole == GlobalRole.director && car.companyId != null) {
      final isDirector = await _isDirectorOfCompany(userId, car.companyId!);
      if (isDirector) return true;
    }

    // Менеджер может создавать заявки с правами
    if (userRole == GlobalRole.manager) {
      return await _hasCarPermission(userId, car.id, (perm) => perm.canOrder);
    }

    return false;
  }

  /// Проверить, может ли пользователь подтверждать заявки и редактировать брони
  Future<bool> canConfirmAndEditBookings(String userId, Car car, GlobalRole userRole) async {
    // Директор управляющей компании может подтверждать
    if (userRole == GlobalRole.director && car.companyId != null) {
      final isDirector = await _isDirectorOfCompany(userId, car.companyId!);
      if (isDirector) return true;
    }

    // Менеджер может подтверждать только с правами
    if (userRole == GlobalRole.manager) {
      return await _hasCarPermission(userId, car.id, (perm) => perm.canConfirm);
    }

    return false;
  }

  /// Проверить, может ли пользователь просматривать детали бронирования
  Future<bool> canViewRental(String userId, Rental rental) async {
    // Создатель брони может просматривать
    if (rental.rentalUserId == userId) return true;

    // Владелец автомобиля может просматривать
    if (rental.carOwnerId == userId) return true;

    // Директор управляющей компании может просматривать
    if (rental.managingCompanyId != null) {
      final isDirector = await _isDirectorOfCompany(userId, rental.managingCompanyId!);
      if (isDirector) return true;
    }

    return false;
  }

  /// Проверить, может ли пользователь редактировать бронирование/заявку
  /// 
  /// Правила:
  /// - Менеджер может редактировать СВОИ заявки и бронирования
  /// - Для редактирования ЧУЖИХ требуется право canConfirm
  Future<bool> canEditRental(String userId, Rental rental, GlobalRole userRole) async {
    // Создатель может редактировать свою заявку/бронь
    if (rental.rentalUserId == userId) return true;

    // Директор управляющей компании может редактировать любые брони
    if (userRole == GlobalRole.director && rental.managingCompanyId != null) {
      return await _isDirectorOfCompany(userId, rental.managingCompanyId!);
    }

    // Менеджер может редактировать чужие брони только с правом canConfirm
    if (userRole == GlobalRole.manager) {
      return await _hasCarPermission(userId, rental.carId, (perm) => perm.canConfirm);
    }

    return false;
  }

  /// Проверить, может ли пользователь выдать и принять автомобиль (начало и завершение аренды)
  Future<bool> canHandoverCar(String userId, Car car, GlobalRole userRole) async {
    // Директор управляющей компании может выдавать и принимать
    if (userRole == GlobalRole.director && car.companyId != null) {
      final isDirector = await _isDirectorOfCompany(userId, car.companyId!);
      if (isDirector) return true;
    }

    // Менеджер может выдавать и принимать с правами
    if (userRole == GlobalRole.manager) {
      return await _hasCarPermission(userId, car.id, (perm) => perm.canHandover);
    }

    return false;
  }

  // ========================================
  // ПРОВЕРКИ ДОСТУПА К ФИНАНСАМ
  // ========================================

  /// Проверить, может ли пользователь просматривать отчеты по аренде
  Future<bool> canViewRentalFinancials(String userId, Rental rental, GlobalRole userRole) async {
    // Владелец автомобиля может видеть финансы
    if (rental.carOwnerId == userId) return true;

    // Директор управляющей компании может видеть финансы
    if (userRole == GlobalRole.director && rental.managingCompanyId != null) {
      return await _isDirectorOfCompany(userId, rental.managingCompanyId!);
    }

    // Создатель брони может видеть свою комиссию
    if (rental.rentalUserId == userId) return true;

    return false;
  }

  // ========================================
  // ПРОВЕРКИ ДОСТУПА К ГАРАЖАМ
  // ========================================

  /// Проверить, может ли пользователь просматривать гараж
  Future<bool> canViewGarage(String userId, Garage garage, GlobalRole userRole) async {
    if (garage is PersonalGarage) {
      // Владелец личного гаража (любая роль может иметь личный гараж)
      if (garage.ownerId == userId) return true;

      // Директор управляющей компании
      if (userRole == GlobalRole.director && garage.managingCompanyId != null) {
        return await _isDirectorOfCompany(userId, garage.managingCompanyId!);
      }
    } else if (garage is CompanyGarage) {
      // Директор корпоративного гаража
      if (garage.directorId == userId) return true;
    }

    return false;
  }

  /// Проверить, может ли пользователь управлять гаражом
  Future<bool> canManageGarage(String userId, Garage garage) async {
    if (garage is PersonalGarage) {
      // Владелец личного гаража может управлять (любая роль)
      return garage.ownerId == userId;
    } else if (garage is CompanyGarage) {
      return garage.directorId == userId;
    }
    return false;
  }

  // ========================================
  // ПРОВЕРКИ УПРАВЛЕНИЯ ПРАВАМИ
  // ========================================

  /// Проверить, может ли пользователь выдавать/изменять права на автомобиль
  /// 
  /// Правила выдачи прав:
  /// 1. canView (просмотр загрузки) - может выдать владелец гаража/компании
  /// 2. Остальные права - только DIRECTOR компании
  /// 3. Для операционных прав авто должно быть под управлением компании (companyId != null)
  Future<bool> canGrantCarPermissions(
    String userId, 
    Car car, 
    GlobalRole userRole,
    CarPermissions permissions,
  ) async {
    // Проверяем, какие права пытаются выдать
    final isOnlyViewPermission = permissions.canView && 
                                  !permissions.canEditCar && 
                                  !permissions.canBook && 
                                  !permissions.canOrder && 
                                  !permissions.canConfirm &&
                                  !permissions.canHandover;

    // Владелец гаража может выдать только право canView
    if (isOnlyViewPermission) {
      return await _isOwnerOfGarage(userId, car.garageId);
    }

    // Для остальных прав требуется DIRECTOR компании
    if (userRole != GlobalRole.director) return false;

    // Авто должно быть под управлением компании
    if (car.companyId == null) return false;

    // DIRECTOR может выдавать права только на авто под управлением своей компании
    return await _isDirectorOfCompany(userId, car.companyId!);
  }

  /// Проверить, может ли пользователь отозвать права на автомобиль
  Future<bool> canRevokeCarPermissions(
    String userId, 
    Car car, 
    GlobalRole userRole,
    CarPermissions permissions,
  ) async {
    // Те же права, что и для выдачи
    return await canGrantCarPermissions(userId, car, userRole, permissions);
  }

  /// Выдать или обновить права пользователя на автомобиль
  /// 
  /// Владелец гаража может выдать право canView.
  /// DIRECTOR компании может выдать операционные права (canEditCar, canBook и т.д.).
  Future<bool> grantCarPermissions({
    required String granterId,
    required GlobalRole granterRole,
    required String managerId,
    required Car car,
    required CarPermissions permissions,
  }) async {
    try {
      // Проверить, может ли granterId выдавать права
      final canGrant = await canGrantCarPermissions(granterId, car, granterRole, permissions);
      if (!canGrant) {
        print('Cannot grant permissions: User does not have authority to grant these permissions');
        return false;
      }

      // Сохранить права в подколлекции car/permissions
      await _firestore
          .collection('cars')
          .doc(car.id)
          .collection('permissions')
          .doc(managerId)
          .set({
        'user_id': managerId,
        'car_id': car.id,
        'can_view': permissions.canView,
        'can_edit_car': permissions.canEditCar,
        'can_book': permissions.canBook,
        'can_order': permissions.canOrder,
        'can_confirm': permissions.canConfirm,
        'can_handover': permissions.canHandover,
        'granted_by': granterId,
        'granted_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error granting car permissions: $e');
      return false;
    }
  }

  /// Отозвать права пользователя на автомобиль
  Future<bool> revokeCarPermissions({
    required String revokerId,
    required GlobalRole revokerRole,
    required String managerId,
    required Car car,
  }) async {
    try {
      // Получить текущие права, чтобы проверить, может ли пользователь их отозвать
      final permDoc = await _firestore
          .collection('cars')
          .doc(car.id)
          .collection('permissions')
          .doc(managerId)
          .get();
      
      if (!permDoc.exists) {
        print('Cannot revoke permissions: No permissions found for this user');
        return false;
      }

      final currentPermissions = CarPermissions.fromFirestore(permDoc.data()!);
      
      // Проверить, может ли revokerId отзывать эти права
      final canRevoke = await canRevokeCarPermissions(revokerId, car, revokerRole, currentPermissions);
      if (!canRevoke) {
        print('Cannot revoke permissions: User does not have authority to revoke these permissions');
        return false;
      }

      // Удалить права из подколлекции
      await _firestore
          .collection('cars')
          .doc(car.id)
          .collection('permissions')
          .doc(managerId)
          .delete();

      return true;
    } catch (e) {
      print('Error revoking car permissions: $e');
      return false;
    }
  }

  /// Выдать право на просмотр календаря (удобный метод для владельцев гаражей)
  /// 
  /// Владелец гаража может использовать этот метод для быстрого предоставления
  /// доступа к просмотру календаря загрузки автомобиля.
  Future<bool> grantViewPermission({
    required String granterId,
    required String userId,
    required Car car,
  }) async {
    // Проверяем, что granter - владелец гаража
    final isOwner = await _isOwnerOfGarage(granterId, car.garageId);
    if (!isOwner) {
      print('Cannot grant view permission: User is not the garage owner');
      return false;
    }

    try {
      await _firestore
          .collection('cars')
          .doc(car.id)
          .collection('permissions')
          .doc(userId)
          .set({
        'user_id': userId,
        'car_id': car.id,
        'can_view': true,
        'can_edit': false,
        'can_book': false,
        'can_confirm_booking': false,
        'can_view_financials': false,
        'granted_by': granterId,
        'granted_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error granting view permission: $e');
      return false;
    }
  }

  // ========================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ========================================

  /// Проверить, является ли пользователь директором компании
  Future<bool> _isDirectorOfCompany(String userId, String companyId) async {
    try {
      final orgDoc = await _firestore.collection('organizations').doc(companyId).get();
      if (!orgDoc.exists) return false;
      
      final directorId = orgDoc.data()?['director_user_id'];
      return directorId == userId;
    } catch (e) {
      return false;
    }
  }

  /// Проверить, является ли пользователь владельцем гаража
  Future<bool> _isOwnerOfGarage(String userId, String garageId) async {
    try {
      final garageDoc = await _firestore.collection('garages').doc(garageId).get();
      if (!garageDoc.exists) return false;
      
      final data = garageDoc.data();
      if (data == null) return false;
      
      // Проверяем owner_id для PersonalGarage
      final ownerId = data['owner_id'];
      if (ownerId != null && ownerId == userId) return true;
      
      // Для CompanyGarage проверяем company_id и является ли пользователь директором
      final garageType = data['garage_type'];
      if (garageType == 'COMPANY') {
        final companyId = data['company_id'];
        if (companyId != null) {
          return await _isDirectorOfCompany(userId, companyId);
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Проверить гранулярные права пользователя на автомобиль
  Future<bool> _hasCarPermission(
    String userId, 
    String carId, 
    bool Function(CarPermissions) check,
  ) async {
    try {
      final permDoc = await _firestore
          .collection('cars')
          .doc(carId)
          .collection('permissions')
          .doc(userId)
          .get();

      if (!permDoc.exists) return false;

      final permission = CarPermissions.fromFirestore(permDoc.data()!);
      return check(permission);
    } catch (e) {
      return false;
    }
  }

  // ========================================
  // МЕТОДЫ ДЛЯ ПОЛУЧЕНИЯ СПИСКОВ С УЧЕТОМ ПРАВ
  // ========================================

  /// Получить все автомобили, доступные пользователю для просмотра
  /// 
  /// Включает:
  /// 1. Автомобили в гаражах, владельцем которых является пользователь
  /// 2. Для DIRECTOR - все автомобили компаний, где он директор
  /// 3. Автомобили, на которые у пользователя есть car_permissions с canView
  Future<List<Car>> getAccessibleCars(String userId, GlobalRole userRole) async {
    final Set<String> carIds = {};
    final List<Car> cars = [];

    try {
      // 1. Автомобили в гаражах пользователя (PersonalGarage или CompanyGarage где он директор)
      final userGaragesSnapshot = await _firestore
          .collection('garages')
          .where('owner_id', isEqualTo: userId)
          .get();
      
      for (final garageDoc in userGaragesSnapshot.docs) {
        final garageCarsSnapshot = await _firestore
            .collection('cars')
            .where('garage_id', isEqualTo: garageDoc.id)
            .get();
        
        for (final carDoc in garageCarsSnapshot.docs) {
          if (!carIds.contains(carDoc.id)) {
            carIds.add(carDoc.id);
            cars.add(Car.fromFirestore(carDoc));
          }
        }
      }

      // 2. Если пользователь - DIRECTOR, получить все авто компаний, где он директор
      if (userRole == GlobalRole.director) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final organizations = List<String>.from(userDoc.data()?['organizations'] ?? []);
        
        for (final orgId in organizations) {
          // Проверяем, является ли пользователь директором этой компании
          final orgDoc = await _firestore.collection('organizations').doc(orgId).get();
          if (orgDoc.exists && orgDoc.data()?['director_user_id'] == userId) {
            final orgCarsSnapshot = await _firestore
                .collection('cars')
                .where('company_id', isEqualTo: orgId)
                .get();
            
            for (final carDoc in orgCarsSnapshot.docs) {
              if (!carIds.contains(carDoc.id)) {
                carIds.add(carDoc.id);
                cars.add(Car.fromFirestore(carDoc));
              }
            }
          }
        }
      }

      // 3. Автомобили с явными правами доступа (car_permissions)
      // Получаем все документы permissions для пользователя
      final allCarsSnapshot = await _firestore.collection('cars').get();
      
      for (final carDoc in allCarsSnapshot.docs) {
        if (carIds.contains(carDoc.id)) continue; // Уже добавлен
        
        final permDoc = await _firestore
            .collection('cars')
            .doc(carDoc.id)
            .collection('permissions')
            .doc(userId)
            .get();
        
        if (permDoc.exists) {
          final permission = CarPermissions.fromFirestore(permDoc.data()!);
          if (permission.canView) {
            carIds.add(carDoc.id);
            cars.add(Car.fromFirestore(carDoc));
          }
        }
      }

      return cars;
    } catch (e) {
      print('Error getting accessible cars: $e');
      return [];
    }
  }

  /// Получить все аренды, доступные пользователю
  Future<List<Rental>> getAccessibleRentals(String userId, GlobalRole userRole) async {
    final List<Rental> rentals = [];

    try {
      // 1. Аренды, созданные пользователем
      final createdRentalsSnapshot = await _firestore
          .collection('rentals')
          .where('rental_user_id', isEqualTo: userId)
          .get();
      
      rentals.addAll(createdRentalsSnapshot.docs.map((doc) => Rental.fromFirestore(doc)));

      // 2. Аренды автомобилей пользователя
      final ownedRentalsSnapshot = await _firestore
          .collection('rentals')
          .where('car_owner_id', isEqualTo: userId)
          .get();
      
      rentals.addAll(ownedRentalsSnapshot.docs.map((doc) => Rental.fromFirestore(doc)));

      // 3. Если директор, аренды его компаний
      if (userRole == GlobalRole.director) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final organizations = List<String>.from(userDoc.data()?['organizations'] ?? []);
        
        for (final orgId in organizations) {
          final orgRentalsSnapshot = await _firestore
              .collection('rentals')
              .where('managing_company_id', isEqualTo: orgId)
              .get();
          
          rentals.addAll(orgRentalsSnapshot.docs.map((doc) => Rental.fromFirestore(doc)));
        }
      }

      // Удалить дубликаты
      final uniqueRentals = <String, Rental>{};
      for (final rental in rentals) {
        uniqueRentals[rental.id] = rental;
      }

      return uniqueRentals.values.toList();
    } catch (e) {
      print('Error getting accessible rentals: $e');
      return [];
    }
  }

  // ========================================
  // ПРОВЕРКИ ДОСТУПА К ОТЧЕТАМ ПО АРЕНДЕ
  // ========================================

  /// Проверить доступ к отчету по аренде (RENT)
  /// Доступ имеют:
  /// - Владелец автопарка (гаража), которому принадлежит авто
  /// - Компания (НЕ директор!), которой принадлежит авто
  /// - rental_user_id (менеджер, создавший аренду)
  Future<bool> canViewRentalReport(String userId, Rental rental) async {
    try {
      // 1. Проверить, является ли пользователь создателем аренды
      if (rental.rentalUserId == userId) return true;

      // 2. Получить информацию об автомобиле
      final carDoc = await _firestore.collection('cars').doc(rental.carId).get();
      if (!carDoc.exists) return false;
      
      final carData = carDoc.data()!;
      final garageId = carData['garage_id'] as String?;
      final companyId = carData['company_id'] as String?;

      // 3. Проверить владельца гаража
      if (garageId != null) {
        final garageDoc = await _firestore.collection('garages').doc(garageId).get();
        if (garageDoc.exists) {
          final ownerId = garageDoc.data()?['owner_id'];
          if (ownerId == userId) return true;
        }
      }

      // 4. Проверить принадлежность к компании (НЕ проверяем роль директора!)
      if (companyId != null) {
        // Проверяем, что пользователь является директором или делегированным менеджером этой компании
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final organizations = List<String>.from(userDoc.data()?['organizations'] ?? []);
        
        if (organizations.contains(companyId)) {
          // Проверить роль директора
          if (userDoc.data()?['global_role'] == 'DIRECTOR') return true;
          
          // Проверить делегированные права
          final delegationDoc = await _firestore
              .collection('companies')
              .doc(companyId)
              .collection('director_delegations')
              .doc(userId)
              .get();
          
          if (delegationDoc.exists && delegationDoc.data()?['is_active'] == true) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('Error checking rental report access: $e');
      return false;
    }
  }

  // ========================================
  // ПРОВЕРКИ ДОСТУПА К КОНТАКТНЫМ ДАННЫМ КЛИЕНТОВ
  // ========================================

  /// Проверить доступ к контактным данным клиента
  /// Доступ имеют:
  /// - Создатель клиента
  /// - Пользователи, которым создатель предоставил доступ
  /// - Директора компаний, которым предоставлен доступ
  Future<bool> canViewClientContacts(String userId, String clientId) async {
    try {
      // 1. Проверить, является ли пользователь создателем
      final clientDoc = await _firestore.collection('clients').doc(clientId).get();
      if (!clientDoc.exists) return false;
      
      final createdBy = clientDoc.data()?['created_by'];
      if (createdBy == userId) return true;

      // 2. Проверить прямые права доступа
      final directPermission = await _firestore
          .collection('clients')
          .doc(clientId)
          .collection('permissions')
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (directPermission.docs.isNotEmpty) return true;

      // 3. Проверить доступ через компанию (только для директоров)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final globalRole = GlobalRole.fromString(userDoc.data()?['global_role'] ?? '');
      
      // Только директор может иметь доступ через компанию
      if (globalRole == GlobalRole.director) {
        final organizations = List<String>.from(userDoc.data()?['organizations'] ?? []);
        
        for (final companyId in organizations) {
          final companyPermission = await _firestore
              .collection('clients')
              .doc(clientId)
              .collection('permissions')
              .where('company_id', isEqualTo: companyId)
              .limit(1)
              .get();
          
          if (companyPermission.docs.isNotEmpty) return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking client contacts access: $e');
      return false;
    }
  }

  /// Предоставить доступ к контактным данным клиента пользователю
  Future<bool> grantClientAccessToUser({
    required String granterId,
    required String clientId,
    required String targetUserId,
  }) async {
    try {
      // Проверить, является ли granter создателем клиента
      final clientDoc = await _firestore.collection('clients').doc(clientId).get();
      if (!clientDoc.exists) return false;
      
      final createdBy = clientDoc.data()?['created_by'];
      if (createdBy != granterId) return false;

      // Создать запись о доступе
      await _firestore
          .collection('clients')
          .doc(clientId)
          .collection('permissions')
          .add({
        'client_id': clientId,
        'user_id': targetUserId,
        'granted_by': granterId,
        'granted_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error granting client access to user: $e');
      return false;
    }
  }

  /// Предоставить доступ к контактным данным клиента компании
  Future<bool> grantClientAccessToCompany({
    required String granterId,
    required String clientId,
    required String targetCompanyId,
  }) async {
    try {
      // Проверить, является ли granter создателем клиента
      final clientDoc = await _firestore.collection('clients').doc(clientId).get();
      if (!clientDoc.exists) return false;
      
      final createdBy = clientDoc.data()?['created_by'];
      if (createdBy != granterId) return false;

      // Создать запись о доступе
      await _firestore
          .collection('clients')
          .doc(clientId)
          .collection('permissions')
          .add({
        'client_id': clientId,
        'company_id': targetCompanyId,
        'granted_by': granterId,
        'granted_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error granting client access to company: $e');
      return false;
    }
  }

  // ========================================
  // ДЕЛЕГИРОВАНИЕ ПРАВ ДИРЕКТОРА
  // ========================================

  /// Проверить, имеет ли пользователь делегированные права директора
  Future<bool> hasDelegatedDirectorRights(String userId, String companyId) async {
    try {
      final delegationDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('director_delegations')
          .doc(userId)
          .get();
      
      return delegationDoc.exists && delegationDoc.data()?['is_active'] == true;
    } catch (e) {
      print('Error checking delegated director rights: $e');
      return false;
    }
  }

  /// Делегировать права директора менеджеру
  /// Передаются все права, кроме закрытия компании
  Future<bool> delegateDirectorRights({
    required String directorId,
    required String managerId,
    required String companyId,
  }) async {
    try {
      // Проверить, что directorId действительно директор компании
      final userDoc = await _firestore.collection('users').doc(directorId).get();
      if (!userDoc.exists) return false;
      
      final organizations = List<String>.from(userDoc.data()?['organizations'] ?? []);
      final globalRole = GlobalRole.fromString(userDoc.data()?['global_role'] ?? '');
      
      if (globalRole != GlobalRole.director || !organizations.contains(companyId)) {
        return false;
      }

      // Создать делегацию
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('director_delegations')
          .doc(managerId)
          .set({
        'company_id': companyId,
        'user_id': managerId,
        'granted_by': directorId,
        'granted_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });

      return true;
    } catch (e) {
      print('Error delegating director rights: $e');
      return false;
    }
  }

  /// Отозвать делегированные права директора
  Future<bool> revokeDelegatedDirectorRights({
    required String directorId,
    required String managerId,
    required String companyId,
  }) async {
    try {
      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('director_delegations')
          .doc(managerId)
          .update({'is_active': false});

      return true;
    } catch (e) {
      print('Error revoking delegated director rights: $e');
      return false;
    }
  }

  // ========================================
  // УПРАВЛЕНИЕ КОМПАНИЯМИ
  // ========================================

  /// Проверить, может ли пользователь закрыть компанию
  /// Только создатель компании (владелец) может её закрыть
  Future<bool> canCloseCompany(String userId, String companyId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final ownedCompanyId = userDoc.data()?['owned_company_id'];
      return ownedCompanyId == companyId;
    } catch (e) {
      print('Error checking company close permission: $e');
      return false;
    }
  }

  /// Проверить, может ли пользователь создать компанию
  /// Каждый пользователь может создать только одну компанию
  Future<bool> canCreateCompany(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final ownedCompanyId = userDoc.data()?['owned_company_id'];
      return ownedCompanyId == null;
    } catch (e) {
      print('Error checking company creation permission: $e');
      return false;
    }
  }
}
