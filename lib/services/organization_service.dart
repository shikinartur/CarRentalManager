import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'firestore_service.dart';

class OrganizationService extends FirestoreService<Organization> {
  static final OrganizationService _instance = OrganizationService._internal();
  factory OrganizationService() => _instance;
  OrganizationService._internal();

  @override
  CollectionReference get collection => 
      FirebaseFirestore.instance.collection('organizations');

  @override
  Organization fromFirestore(DocumentSnapshot doc) => Organization.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Organization organization) => organization.toFirestore();

  /// Создать организацию с автогенерацией ID
  Future<String> createOrganization(Organization organization) async {
    try {
      final orgId = Organization.generateOrgId();
      final orgWithId = organization.copyWith();
      
      await createWithId(orgId, orgWithId);
      return orgId;
    } catch (e) {
      throw Exception('Ошибка создания организации: $e');
    }
  }

  /// Получить организации пользователя
  Future<List<Organization>> getUserOrganizations(List<String> organizationIds) async {
    if (organizationIds.isEmpty) return [];

    try {
      // Firestore имеет ограничение на 10 элементов в whereIn
      // Разбиваем на части если больше 10
      final List<Organization> allOrganizations = [];
      
      for (int i = 0; i < organizationIds.length; i += 10) {
        final batch = organizationIds.skip(i).take(10).toList();
        final snapshot = await collection
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        allOrganizations.addAll(
          snapshot.docs.map((doc) => fromFirestore(doc)).toList()
        );
      }
      
      return allOrganizations;
    } catch (e) {
      throw Exception('Ошибка получения организаций пользователя: $e');
    }
  }

  /// Получить активные организации
  Future<List<Organization>> getActiveOrganizations() async {
    return getWhere('is_active', true);
  }

  /// Получить организации по директору
  Future<List<Organization>> getOrganizationsByDirector(String directorUserId) async {
    return getWhere('director_user_id', directorUserId);
  }

  /// Поиск организаций по названию
  Future<List<Organization>> searchByName(String searchTerm) async {
    try {
      // Firestore не поддерживает полнотекстовый поиск
      // Используем простой подход с фильтрацией
      final allOrgs = await getActiveOrganizations();
      
      return allOrgs.where((org) => 
          org.name.toLowerCase().contains(searchTerm.toLowerCase())
      ).toList();
    } catch (e) {
      throw Exception('Ошибка поиска организаций: $e');
    }
  }

  /// Деактивировать организацию
  Future<void> deactivateOrganization(String organizationId) async {
    await updateFields(organizationId, {'is_active': false});
  }

  /// Активировать организацию
  Future<void> activateOrganization(String organizationId) async {
    await updateFields(organizationId, {'is_active': true});
  }

  /// Изменить директора организации
  Future<void> changeDirector(String organizationId, String newDirectorId) async {
    await updateFields(organizationId, {'director_user_id': newDirectorId});
  }

  /// Проверить, является ли пользователь директором организации
  Future<bool> isUserDirector(String userId, String organizationId) async {
    try {
      final org = await getById(organizationId);
      return org?.directorUserId == userId;
    } catch (e) {
      return false;
    }
  }

  /// Получить статистику организации
  Future<Map<String, dynamic>> getOrganizationStats(String organizationId) async {
    try {
      // Здесь можно добавить подсчет автомобилей, аренд и т.д.
      // Пока возвращаем базовую информацию
      final org = await getById(organizationId);
      if (org == null) {
        throw Exception('Организация не найдена');
      }

      return {
        'id': org.id,
        'name': org.name,
        'is_active': org.isActive,
        'created_at': org.createdAt,
        // TODO: Добавить подсчет автомобилей, аренд, пользователей
        'cars_count': 0,
        'active_rentals': 0,
        'users_count': 0,
      };
    } catch (e) {
      throw Exception('Ошибка получения статистики организации: $e');
    }
  }

  /// Подписаться на изменения активных организаций
  Stream<List<Organization>> streamActiveOrganizations() {
    return streamWhere('is_active', true);
  }

  /// Подписаться на изменения организаций пользователя
  Stream<List<Organization>> streamUserOrganizations(List<String> organizationIds) {
    if (organizationIds.isEmpty) {
      return Stream.value([]);
    }

    // Для простоты берем только первые 10 организаций
    final limitedIds = organizationIds.take(10).toList();
    
    return collection
        .where(FieldPath.documentId, whereIn: limitedIds)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => fromFirestore(doc)).toList());
  }
}