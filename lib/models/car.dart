import 'package:cloud_firestore/cloud_firestore.dart';
import 'garage.dart';

enum CarStatus {
  available('AVAILABLE'),
  inMaintenance('IN_MAINTENANCE'),
  sold('SOLD');

  const CarStatus(this.value);
  final String value;

  static CarStatus fromString(String value) {
    return CarStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CarStatus.available,
    );
  }
}

/// Модель автомобиля с двойной принадлежностью:
/// - Владелец (owner) - кому принадлежит автомобиль юридически
/// - Управляющий (manager/garage) - кто имеет право управлять и сдавать в аренду
/// 
/// ВАЖНО: Каждый автомобиль принадлежит ТОЛЬКО ОДНОМУ гаражу:
/// - Либо PersonalGarage (личный гараж пользователя)
/// - Либо CompanyGarage (корпоративный гараж компании)
/// Смена гаража возможна через передачу автомобиля
class Car {
  final String id;
  
  // === ВЛАДЕНИЕ (Ownership) ===
  final String ownerId;        // USER_id владельца
  final String garageId;       // ID гаража (ОДИН на автомобиль: personal_garage_XXX ИЛИ COMPANY_garage_XXX)
  final GarageType garageType; // Тип гаража (PERSONAL или COMPANY)
  
  // === УПРАВЛЕНИЕ (Management) ===
  final String? companyId;     // COMPANY_id управляющей компании (если есть)
  
  // === УСТАРЕВШИЕ ПОЛЯ (для обратной совместимости) ===
  @Deprecated('Use ownerId and garageId instead')
  final String? organizationId; // Старое поле, будет удалено
  
  // === ОСНОВНЫЕ ДАННЫЕ ===
  final String make;
  final String model;
  final String licensePlate;
  final CarStatus status;
  final double dailyRate;
  final double monthlyRate;
  final List<String> photosLinks; // Ссылки на публичные фото
  final int? year;
  final String? color;
  final String? vin;
  final DateTime createdAt;
  final DateTime updatedAt;

  Car({
    required this.id,
    required this.ownerId,
    required this.garageId,
    required this.garageType,
    this.companyId,
    @Deprecated('Use ownerId and garageId instead') this.organizationId,
    required this.make,
    required this.model,
    required this.licensePlate,
    required this.status,
    required this.dailyRate,
    required this.monthlyRate,
    required this.photosLinks,
    this.year,
    this.color,
    this.vin,
    required this.createdAt,
    required this.updatedAt,
  });

  // Получить полное название автомобиля
  String get fullName => '$make $model${year != null ? ' ($year)' : ''}';

  // Проверить доступность для бронирования
  bool get isAvailable => status == CarStatus.available;
  
  // Проверить, является ли автомобиль личным (принадлежит пользователю через PersonalGarage)
  bool get isPersonal => garageType == GarageType.personal;
  
  // Проверить, является ли автомобиль корпоративным (принадлежит компании через CompanyGarage)
  bool get isCompany => garageType == GarageType.company;
  
  // Проверить, есть ли управляющая компания
  bool get hasManagingCompany => companyId != null;
  
  /// Валидация: проверить соответствие garageId и garageType
  /// garageId должен начинаться с префикса, соответствующего типу гаража
  bool validateGarageConsistency() {
    if (garageType == GarageType.personal) {
      return garageId.startsWith('personal_garage_');
    } else if (garageType == GarageType.company) {
      return garageId.startsWith('COMPANY_garage_');
    }
    return false;
  }

  // Создать из Firestore документа
  factory Car.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Car(
      id: doc.id,
      ownerId: data['owner_id'] ?? data['organization_id'] ?? '',
      garageId: data['garage_id'] ?? '',
      garageType: GarageType.fromString(data['garage_type'] ?? 'COMPANY'),
      companyId: data['company_id'],
      organizationId: data['organization_id'], // Для обратной совместимости
      make: data['make'] ?? '',
      model: data['model'] ?? '',
      licensePlate: data['license_plate'] ?? '',
      status: CarStatus.fromString(data['status'] ?? 'AVAILABLE'),
      dailyRate: (data['daily_rate'] ?? 0.0).toDouble(),
      monthlyRate: (data['monthly_rate'] ?? 0.0).toDouble(),
      photosLinks: List<String>.from(data['photos_links'] ?? []),
      year: data['year']?.toInt(),
      color: data['color'],
      vin: data['vin'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'owner_id': ownerId,
      'garage_id': garageId,
      'garage_type': garageType.value,
      if (companyId != null) 'company_id': companyId,
      'make': make,
      'model': model,
      'license_plate': licensePlate,
      'status': status.value,
      'daily_rate': dailyRate,
      'monthly_rate': monthlyRate,
      'photos_links': photosLinks,
      if (year != null) 'year': year,
      if (color != null) 'color': color,
      if (vin != null) 'vin': vin,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Создать копию с изменениями
  Car copyWith({
    String? ownerId,
    String? garageId,
    GarageType? garageType,
    String? companyId,
    String? make,
    String? model,
    String? licensePlate,
    CarStatus? status,
    double? dailyRate,
    double? monthlyRate,
    List<String>? photosLinks,
    int? year,
    String? color,
    String? vin,
  }) {
    return Car(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      garageId: garageId ?? this.garageId,
      garageType: garageType ?? this.garageType,
      companyId: companyId ?? this.companyId,
      organizationId: organizationId,
      make: make ?? this.make,
      model: model ?? this.model,
      licensePlate: licensePlate ?? this.licensePlate,
      status: status ?? this.status,
      dailyRate: dailyRate ?? this.dailyRate,
      monthlyRate: monthlyRate ?? this.monthlyRate,
      photosLinks: photosLinks ?? this.photosLinks,
      year: year ?? this.year,
      color: color ?? this.color,
      vin: vin ?? this.vin,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Car(id: $id, fullName: $fullName, licensePlate: $licensePlate, status: ${status.value})';
  }
}