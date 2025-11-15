import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firestore_service.dart';

class ClientService extends FirestoreService<Client> {
  static final ClientService _instance = ClientService._internal();
  factory ClientService() => _instance;
  ClientService._internal();

  @override
  CollectionReference get collection => 
      FirebaseFirestore.instance.collection('clients');

  @override
  Client fromFirestore(DocumentSnapshot doc) => Client.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Client client) => client.toFirestore();

  /// Получить клиентов организации
  Future<List<Client>> getOrganizationClients(String organizationId) async {
    return getWhere('organization_id', organizationId);
  }

  /// Поиск клиентов по имени, телефону или email
  Future<List<Client>> searchClients(String organizationId, String searchTerm) async {
    try {
      final orgClients = await getOrganizationClients(organizationId);
      
      return orgClients.where((client) {
        final searchLower = searchTerm.toLowerCase();
        return client.name.toLowerCase().contains(searchLower) ||
               client.phone.toLowerCase().contains(searchLower) ||
               client.email.toLowerCase().contains(searchLower);
      }).toList();
    } catch (e) {
      throw Exception('Ошибка поиска клиентов: $e');
    }
  }

  /// Найти клиента по телефону
  Future<Client?> findClientByPhone(String organizationId, String phone) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка поиска клиента по телефону: $e');
    }
  }

  /// Найти клиента по email
  Future<Client?> findClientByEmail(String organizationId, String email) async {
    try {
      final snapshot = await collection
          .where('organization_id', isEqualTo: organizationId)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка поиска клиента по email: $e');
    }
  }

  /// Проверить существование клиента в организации
  Future<bool> clientExists(String organizationId, String phone, {String? email}) async {
    try {
      final phoneExists = await findClientByPhone(organizationId, phone) != null;
      if (phoneExists) return true;

      if (email != null && email.isNotEmpty) {
        final emailExists = await findClientByEmail(organizationId, email) != null;
        if (emailExists) return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Получить всех клиентов с базовой информацией
  Future<List<Client>> getClientsWithBasicInfo(String organizationId) async {
    try {
      final allClients = await getOrganizationClients(organizationId);
      return allClients.where((client) => client.hasBasicInfo).toList();
    } catch (e) {
      throw Exception('Ошибка получения клиентов с базовой информацией: $e');
    }
  }

  /// Обновить информацию о клиенте
  Future<void> updateClientInfo(String clientId, {
    String? name,
    String? phone,
    String? email,
    String? driverLicenseInfo,
    String? passportInfo,
  }) async {
    final Map<String, dynamic> updates = {
      'updated_at': Timestamp.now(),
    };

    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;
    if (driverLicenseInfo != null) updates['driver_license_info'] = driverLicenseInfo;
    if (passportInfo != null) updates['passport_info'] = passportInfo;

    await updateFields(clientId, updates);
  }

  /// Получить историю аренд клиента
  Future<List<Rental>> getClientRentalsHistory(String clientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('client_id', isEqualTo: clientId)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) => Rental.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения истории аренд клиента: $e');
    }
  }

  /// Получить активную аренду клиента
  Future<Rental?> getClientActiveRental(String clientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rentals')
          .where('client_id', isEqualTo: clientId)
          .where('status', isEqualTo: RentalStatus.active.name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Rental.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка получения активной аренды клиента: $e');
    }
  }

  /// Получить статистику клиента
  Future<Map<String, dynamic>> getClientStats(String clientId) async {
    try {
      final client = await getById(clientId);
      if (client == null) {
        throw Exception('Клиент не найден');
      }

      final rentalsHistory = await getClientRentalsHistory(clientId);
      final activeRental = await getClientActiveRental(clientId);

      final completedRentals = rentalsHistory
          .where((rental) => rental.status == RentalStatus.completed)
          .toList();

      final totalSpent = completedRentals.fold(
        0.0, 
        (total, rental) => total + rental.priceAmount
      );

      return {
        'client_id': clientId,
        'full_name': client.name,
        'total_rentals': rentalsHistory.length,
        'completed_rentals': completedRentals.length,
        'active_rentals': activeRental != null ? 1 : 0,
        'total_spent': totalSpent,
        'has_basic_info': client.hasBasicInfo,
        'registration_date': client.createdAt,
      };
    } catch (e) {
      throw Exception('Ошибка получения статистики клиента: $e');
    }
  }

  /// Получить топ клиентов по количеству аренд
  Future<List<Map<String, dynamic>>> getTopClients(String organizationId, {int limit = 10}) async {
    try {
      final clients = await getOrganizationClients(organizationId);
      final List<Map<String, dynamic>> clientStats = [];

      for (final client in clients) {
        final rentals = await getClientRentalsHistory(client.id);
        final completedRentals = rentals
            .where((rental) => rental.status == RentalStatus.completed)
            .toList();

        clientStats.add({
          'client': client,
          'total_rentals': rentals.length,
          'completed_rentals': completedRentals.length,
          'total_spent': completedRentals.fold(
            0.0, 
            (total, rental) => total + rental.priceAmount
          ),
        });
      }

      // Сортируем по количеству завершенных аренд
      clientStats.sort((a, b) => (b['completed_rentals'] as int).compareTo(a['completed_rentals'] as int));

      return clientStats.take(limit).toList();
    } catch (e) {
      throw Exception('Ошибка получения топ клиентов: $e');
    }
  }

  /// Экспорт клиентов организации в CSV формат
  Future<String> exportClientsToCSV(String organizationId) async {
    try {
      final clients = await getOrganizationClients(organizationId);
      
      final csvHeader = 'ID,Name,Phone,Email,Driver License Info,Passport Info,Created At\n';
      final csvRows = clients.map((client) => 
          '${client.id},'
          '${client.name},'
          '${client.phone},'
          '${client.email},'
          '${client.driverLicenseInfo ?? ''},'
          '${client.passportInfo ?? ''},'
          '${client.createdAt.toIso8601String()}'
      ).join('\n');

      return csvHeader + csvRows;
    } catch (e) {
      throw Exception('Ошибка экспорта клиентов: $e');
    }
  }

  /// Подписаться на изменения клиентов организации
  Stream<List<Client>> streamOrganizationClients(String organizationId) {
    return streamWhere('organization_id', organizationId);
  }

  /// Подписаться на изменения клиентов с базовой информацией
  Stream<List<Client>> streamClientsWithBasicInfo(String organizationId) {
    return streamWhere('organization_id', organizationId)
        .map((clients) => clients.where((client) => client.hasBasicInfo).toList());
  }

  /// Подписаться на изменения конкретного клиента
  Stream<Client?> streamClient(String clientId) {
    return streamById(clientId);
  }
}