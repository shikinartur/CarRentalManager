import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firestore_service.dart';

class RentalService extends FirestoreService<Rental> {
  static final RentalService _instance = RentalService._internal();
  factory RentalService() => _instance;
  RentalService._internal();

  @override
  CollectionReference get collection => 
      FirebaseFirestore.instance.collection('rentals');

  @override
  Rental fromFirestore(DocumentSnapshot doc) => Rental.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Rental rental) => rental.toFirestore();

  /// Создать новую аренду
  Future<String> createRental(Rental rental) async {
    try {
      // Проверяем доступность автомобиля
      final car = await FirebaseFirestore.instance
          .collection('cars')
          .doc(rental.carId)
          .get();
      
      if (!car.exists) {
        throw Exception('Автомобиль не найден');
      }

      final carData = car.data() as Map<String, dynamic>;
      final carStatus = CarStatus.fromString(carData['status'] as String);
      
      if (carStatus != CarStatus.available) {
        throw Exception('Автомобиль недоступен для аренды');
      }

      // Создаем аренду
      final rentalId = await create(rental);
      
      // Обновляем статус автомобиля (если нужно)
      // await FirebaseFirestore.instance
      //     .collection('cars')
      //     .doc(rental.carId)
      //     .update({'status': CarStatus.reserved.value});

      return rentalId;
    } catch (e) {
      throw Exception('Ошибка создания аренды: $e');
    }
  }

  /// Получить аренды организации
  Future<List<Rental>> getOrganizationRentals(String organizationId) async {
    return getWhere('organization_id', organizationId);
  }

  /// Получить активные аренды организации
  Future<List<Rental>> getActiveRentals(String organizationId) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('status', isEqualTo: RentalStatus.active.name)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения активных аренд: $e');
    }
  }

  /// Получить аренды по статусу
  Future<List<Rental>> getRentalsByStatus(String organizationId, RentalStatus status) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('status', isEqualTo: status.name)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения аренд по статусу: $e');
    }
  }

  /// Получить аренды клиента
  Future<List<Rental>> getClientRentals(String clientId) async {
    return getWhere('client_id', clientId);
  }

  /// Получить аренды автомобиля
  Future<List<Rental>> getCarRentals(String carId) async {
    return getWhere('car_id', carId);
  }

  /// Получить текущую аренду автомобиля
  Future<Rental?> getCurrentCarRental(String carId) async {
    try {
      final snapshot = await collection
          .where('car_id', isEqualTo: carId)
          .where('status', isEqualTo: RentalStatus.active.name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка получения текущей аренды автомобиля: $e');
    }
  }

  /// Подтвердить аренду
  Future<void> confirmRental(String rentalId) async {
    await updateFields(rentalId, {'status': RentalStatus.active.name});
  }

  /// Завершить аренду
  Future<void> completeRental(String rentalId, {int? finalMileage}) async {
    final Map<String, dynamic> updates = {
      'status': RentalStatus.completed.name,
      'actual_end_date': Timestamp.now(),
    };

    if (finalMileage != null) {
      updates['final_mileage'] = finalMileage;
    }

    await updateFields(rentalId, updates);
  }

  /// Отменить аренду (переводим в техническое обслуживание)
  Future<void> cancelRental(String rentalId, String reason) async {
    await updateFields(rentalId, {
      'status': RentalStatus.maintenance.name,
      'notes': reason,
      'updated_at': Timestamp.now(),
    });
  }

  /// Получить аренды за период
  Future<List<Rental>> getRentalsInPeriod(
    String organizationId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('start_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('start_date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения аренд за период: $e');
    }
  }

  /// Получить просроченные аренды
  Future<List<Rental>> getOverdueRentals(String organizationId) async {
    try {
      final now = Timestamp.now();
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('status', isEqualTo: RentalStatus.active.name)
          .where('end_date', isLessThan: now)
          .get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения просроченных аренд: $e');
    }
  }

  /// Продлить аренду
  Future<void> extendRental(String rentalId, DateTime newEndDate, double additionalCost) async {
    await updateFields(rentalId, {
      'end_date': Timestamp.fromDate(newEndDate),
      'total_cost': FieldValue.increment(additionalCost),
    });
  }

  /// Получить статистику аренд организации
  Future<Map<String, dynamic>> getOrganizationRentalsStats(String organizationId) async {
    try {
      final rentals = await getOrganizationRentals(organizationId);
      
      final stats = <String, int>{};
      double totalRevenue = 0;
      
      for (final status in RentalStatus.values) {
        final statusRentals = rentals.where((rental) => rental.status == status);
        stats[status.name] = statusRentals.length;
        
        if (status == RentalStatus.completed) {
          totalRevenue = statusRentals.fold(0.0, (total, rental) => total + rental.priceAmount);
        }
      }

      return {
        'total': rentals.length,
        'by_status': stats,
        'total_revenue': totalRevenue,
        'active_rentals': stats[RentalStatus.active.name] ?? 0,
        'completed_rentals': stats[RentalStatus.completed.name] ?? 0,
      };
    } catch (e) {
      throw Exception('Ошибка получения статистики аренд: $e');
    }
  }

  /// Поиск аренд по клиенту
  Future<List<Rental>> searchRentalsByClient(String organizationId, String searchTerm) async {
    try {
      // Сначала получаем всех клиентов, которые соответствуют поиску
      final clientsSnapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('organization_id', isEqualTo: organizationId)
          .get();

      final matchingClientIds = clientsSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final firstName = (data['first_name'] as String? ?? '').toLowerCase();
            final lastName = (data['last_name'] as String? ?? '').toLowerCase();
            final phone = (data['phone'] as String? ?? '').toLowerCase();
            final email = (data['email'] as String? ?? '').toLowerCase();
            final search = searchTerm.toLowerCase();
            
            return firstName.contains(search) || 
                   lastName.contains(search) || 
                   phone.contains(search) || 
                   email.contains(search);
          })
          .map((doc) => doc.id)
          .toList();

      if (matchingClientIds.isEmpty) return [];

      // Получаем аренды для найденных клиентов
      final List<Rental> allRentals = [];
      
      for (int i = 0; i < matchingClientIds.length; i += 10) {
        final batch = matchingClientIds.skip(i).take(10).toList();
        final snapshot = await collection
            .where('organization_id', isEqualTo: organizationId)
            .where('client_id', whereIn: batch)
            .get();
        
        allRentals.addAll(
          snapshot.docs.map((doc) => fromFirestore(doc)).toList()
        );
      }
      
      return allRentals;
    } catch (e) {
      throw Exception('Ошибка поиска аренд по клиенту: $e');
    }
  }

  /// Подписаться на изменения активных аренд
  Stream<List<Rental>> streamActiveRentals(String organizationId) {
    return collection
        .where('organization_id', isEqualTo: organizationId)
        .where('status', isEqualTo: RentalStatus.active.name)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }

  /// Подписаться на изменения аренд организации
  Stream<List<Rental>> streamOrganizationRentals(String organizationId) {
    return streamWhere('organization_id', organizationId);
  }

  /// Подписаться на изменения конкретной аренды
  Stream<Rental?> streamRental(String rentalId) {
    return streamById(rentalId);
  }
}