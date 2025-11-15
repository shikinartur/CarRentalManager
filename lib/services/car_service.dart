import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firestore_service.dart';

class CarService extends FirestoreService<Car> {
  static final CarService _instance = CarService._internal();
  factory CarService() => _instance;
  CarService._internal();

  @override
  CollectionReference get collection => 
      FirebaseFirestore.instance.collection('cars');

  @override
  Car fromFirestore(DocumentSnapshot doc) => Car.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Car car) => car.toFirestore();

  /// Получить автомобили организации
  Future<List<Car>> getOrganizationCars(String organizationId) async {
    return getWhere('organization_id', organizationId);
  }

  /// Получить доступные автомобили организации
  Future<List<Car>> getAvailableCars(String organizationId) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('status', isEqualTo: CarStatus.available.name)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения доступных автомобилей: $e');
    }
  }

  /// Получить автомобили по статусу
  Future<List<Car>> getCarsByStatus(String organizationId, CarStatus status) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('status', isEqualTo: status.name)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения автомобилей по статусу: $e');
    }
  }

  /// Поиск автомобилей по модели/марке
  Future<List<Car>> searchCars(String organizationId, String searchTerm) async {
    try {
      final orgCars = await getOrganizationCars(organizationId);
      
      return orgCars.where((car) {
        final searchLower = searchTerm.toLowerCase();
        return car.make.toLowerCase().contains(searchLower) ||
               car.model.toLowerCase().contains(searchLower) ||
               car.licensePlate.toLowerCase().contains(searchLower);
      }).toList();
    } catch (e) {
      throw Exception('Ошибка поиска автомобилей: $e');
    }
  }

  /// Изменить статус автомобиля
  Future<void> updateCarStatus(String carId, CarStatus status) async {
    await updateFields(carId, {'status': status.name});
  }

  /// Сделать автомобиль доступным
  Future<void> makeCarAvailable(String carId) async {
    await updateCarStatus(carId, CarStatus.available);
  }

  /// Отправить автомобиль на техническое обслуживание
  Future<void> sendCarToMaintenance(String carId) async {
    await updateCarStatus(carId, CarStatus.inMaintenance);
  }

  /// Пометить автомобиль как проданный
  Future<void> markCarAsSold(String carId) async {
    await updateCarStatus(carId, CarStatus.sold);
  }

  /// Получить статистику автомобилей организации
  Future<Map<String, dynamic>> getOrganizationCarsStats(String organizationId) async {
    try {
      final cars = await getOrganizationCars(organizationId);
      
      final stats = <String, int>{};
      for (final status in CarStatus.values) {
        stats[status.name] = cars.where((car) => car.status == status).length;
      }

      return {
        'total': cars.length,
        'by_status': stats,
        'active_cars': stats[CarStatus.available.name] ?? 0,
        'inactive_cars': (stats[CarStatus.inMaintenance.name] ?? 0) + (stats[CarStatus.sold.name] ?? 0),
      };
    } catch (e) {
      throw Exception('Ошибка получения статистики автомобилей: $e');
    }
  }

  /// Проверить доступность автомобиля
  Future<bool> isCarAvailable(String carId) async {
    try {
      final car = await getById(carId);
      return car?.status == CarStatus.available;
    } catch (e) {
      return false;
    }
  }

  /// Получить автомобили по ценовому диапазону
  Future<List<Car>> getCarsByPriceRange(
    String organizationId,
    double minPrice,
    double maxPrice,
  ) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('daily_rate', isGreaterThanOrEqualTo: minPrice)
          .where('daily_rate', isLessThanOrEqualTo: maxPrice)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения автомобилей по цене: $e');
    }
  }

  /// Получить автомобили по году выпуска
  Future<List<Car>> getCarsByYearRange(
    String organizationId,
    int minYear,
    int maxYear,
  ) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('year', isGreaterThanOrEqualTo: minYear)
          .where('year', isLessThanOrEqualTo: maxYear)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения автомобилей по году: $e');
    }
  }

  /// Обновить пробег автомобиля
  Future<void> updateMileage(String carId, int newMileage) async {
    await updateFields(carId, {'mileage': newMileage});
  }

  /// Обновить дневную ставку
  Future<void> updateDailyRate(String carId, double newRate) async {
    await updateFields(carId, {'daily_rate': newRate});
  }

  /// Подписаться на изменения автомобилей организации
  Stream<List<Car>> streamOrganizationCars(String organizationId) {
    return streamWhere('organization_id', organizationId);
  }

  /// Подписаться на изменения доступных автомобилей
  Stream<List<Car>> streamAvailableCars(String organizationId) {
    return collection
        .where('organization_id', isEqualTo: organizationId)
        .where('status', isEqualTo: CarStatus.available.name)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  /// Подписаться на изменения статуса конкретного автомобиля
  Stream<Car?> streamCarStatus(String carId) {
    return streamById(carId);
  }

  // ============================================
  // МЕТОДЫ ВАЛИДАЦИИ ГАРАЖА (ОДИН гараж на авто)
  // ============================================

  /// Получить все автомобили в гараже
  /// ВАЖНО: Каждый автомобиль принадлежит только ОДНОМУ гаражу
  Future<List<Car>> getCarsByGarage(String garageId) async {
    try {
      final snapshot = await collection
          .where('garage_id', isEqualTo: garageId)
          .get();
      
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения автомобилей гаража: $e');
    }
  }

  /// Передать автомобиль в другой гараж
  /// Замена ОДНОГО гаража на другой ОДИН гараж
  Future<void> transferCarToGarage({
    required String carId,
    required String newOwnerId,
    required String newGarageId,
    required String newGarageType, // 'PERSONAL' или 'COMPANY'
    String? newCompanyId,
    required String transferredBy,
  }) async {
    // Валидация формата garageId
    if (newGarageType == 'PERSONAL' && !newGarageId.startsWith('personal_garage_')) {
      throw ArgumentError('Неверный формат ID личного гаража');
    }
    
    if (newGarageType == 'COMPANY' && !newGarageId.startsWith('COMPANY_garage_')) {
      throw ArgumentError('Неверный формат ID корпоративного гаража');
    }

    // Проверить существование нового гаража
    final garageDoc = await FirebaseFirestore.instance
        .collection('garages')
        .doc(newGarageId)
        .get();
        
    if (!garageDoc.exists) {
      throw ArgumentError('Гараж с ID $newGarageId не существует');
    }

    // Обновить автомобиль (замена гаража)
    await updateFields(carId, {
      'owner_id': newOwnerId,
      'garage_id': newGarageId,
      'garage_type': newGarageType,
      if (newCompanyId != null) 'company_id': newCompanyId,
      'transferred_by': transferredBy,
      'transferred_at': Timestamp.now(),
    });
  }

  /// Валидировать соответствие автомобиля гаражу
  Future<bool> validateCarGarageConsistency(String carId) async {
    try {
      final car = await getById(carId);
      if (car == null) return false;
      
      // Проверка 1: Валидация префикса
      if (!car.validateGarageConsistency()) {
        return false;
      }
      
      // Проверка 2: Существование гаража
      final garageDoc = await FirebaseFirestore.instance
          .collection('garages')
          .doc(car.garageId)
          .get();
          
      if (!garageDoc.exists) return false;
      
      // Проверка 3: Соответствие типа
      final garageData = garageDoc.data()!;
      final garageTypeFromDb = garageData['type'];
      
      return garageTypeFromDb == car.garageType.value;
    } catch (e) {
      return false;
    }
  }
}
