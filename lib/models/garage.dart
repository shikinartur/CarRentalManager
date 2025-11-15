import 'package:cloud_firestore/cloud_firestore.dart';

/// Тип гаража (владения автомобилями)
enum GarageType {
  personal('PERSONAL'),   // Личный гараж владельца (OWNER)
  company('COMPANY');     // Корпоративный гараж компании (DIRECTOR)

  const GarageType(this.value);
  final String value;

  static GarageType fromString(String value) {
    return GarageType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => GarageType.company,
    );
  }
}

/// Абстрактный базовый класс для гаража
abstract class Garage {
  final String id;
  final GarageType type;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Garage({
    required this.id,
    required this.type,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore();
}

/// Личный гараж пользователя
/// Любой USER (INVESTOR, DIRECTOR, MANAGER) может владеть личными автомобилями
/// INVESTOR - владелец-инвестор, может передать управление компании
/// DIRECTOR - может иметь личные авто помимо корпоративных
/// MANAGER - может владеть авто, но управлять только через компанию
class PersonalGarage extends Garage {
  final String ownerId;              // USER_id владельца (любая роль)
  final String? managingCompanyId;   // COMPANY_id управляющей компании (опционально)
  final double commissionRate;       // Процент комиссии управляющей компании

  PersonalGarage({
    required super.id,
    required super.name,
    required this.ownerId,
    this.managingCompanyId,
    this.commissionRate = 0.0,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  }) : super(type: GarageType.personal);

  /// Проверить, есть ли управляющая компания
  bool get hasManagingCompany => managingCompanyId != null;

  /// Создать из Firestore документа
  factory PersonalGarage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PersonalGarage(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['owner_id'] ?? '',
      managingCompanyId: data['managing_company_id'],
      commissionRate: (data['commission_rate'] ?? 0.0).toDouble(),
      isActive: data['is_active'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'name': name,
      'owner_id': ownerId,
      if (managingCompanyId != null) 'managing_company_id': managingCompanyId,
      'commission_rate': commissionRate,
      'is_active': isActive,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Создать копию с изменениями
  PersonalGarage copyWith({
    String? name,
    String? managingCompanyId,
    double? commissionRate,
    bool? isActive,
  }) {
    return PersonalGarage(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      managingCompanyId: managingCompanyId ?? this.managingCompanyId,
      commissionRate: commissionRate ?? this.commissionRate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PersonalGarage(id: $id, owner: $ownerId, managing: $managingCompanyId, active: $isActive)';
  }
}

/// Корпоративный гараж компании (DIRECTOR)
/// Компания владеет автомобилями, DIRECTOR управляет ими
class CompanyGarage extends Garage {
  final String companyId;     // COMPANY_id владеющей компании
  final String directorId;    // USER_id директора, управляющего автопарком

  CompanyGarage({
    required super.id,
    required super.name,
    required this.companyId,
    required this.directorId,
    super.isActive = true,
    required super.createdAt,
    required super.updatedAt,
  }) : super(type: GarageType.company);

  /// Создать из Firestore документа
  factory CompanyGarage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CompanyGarage(
      id: doc.id,
      name: data['name'] ?? '',
      companyId: data['company_id'] ?? '',
      directorId: data['director_id'] ?? '',
      isActive: data['is_active'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'name': name,
      'company_id': companyId,
      'director_id': directorId,
      'is_active': isActive,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Создать копию с изменениями
  CompanyGarage copyWith({
    String? name,
    String? directorId,
    bool? isActive,
  }) {
    return CompanyGarage(
      id: id,
      name: name ?? this.name,
      companyId: companyId,
      directorId: directorId ?? this.directorId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'CompanyGarage(id: $id, company: $companyId, director: $directorId, active: $isActive)';
  }
}

/// Фабрика для создания гаражей из Firestore
class GarageFactory {
  static Garage fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = GarageType.fromString(data['type'] ?? 'COMPANY');
    
    switch (type) {
      case GarageType.personal:
        return PersonalGarage.fromFirestore(doc);
      case GarageType.company:
        return CompanyGarage.fromFirestore(doc);
    }
  }
}
