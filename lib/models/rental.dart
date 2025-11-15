import 'package:cloud_firestore/cloud_firestore.dart';

enum RentalStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  active('ACTIVE'),
  completed('COMPLETED'),
  maintenance('MAINTENANCE');

  const RentalStatus(this.value);
  final String value;

  static RentalStatus fromString(String value) {
    return RentalStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RentalStatus.pending,
    );
  }
}

class Rental {
  final String id;
  
  // === ОСНОВНЫЕ СВЯЗИ ===
  final String carId;           // Ссылка на автомобиль
  final String clientId;        // Ссылка на клиента
  
  // === УЧАСТНИКИ СДЕЛКИ ===
  final String rentalUserId;    // ID пользователя, создавшего бронь (MANAGER/DIRECTOR)
  final String carOwnerId;      // ID владельца автомобиля (из Car.ownerId)
  final String? managingCompanyId; // ID управляющей компании (если есть)
  
  // === УСТАРЕВШИЕ ПОЛЯ (для обратной совместимости) ===
  @Deprecated('Use rentalUserId instead')
  final String? managerId;      // Старое поле
  @Deprecated('Use carOwnerId instead')
  final String? organizationId; // Старое поле
  
  // === ДАТЫ И СТАТУС ===
  final DateTime startDate;
  final DateTime endDate;
  final RentalStatus status;
  
  // === ФИНАНСЫ ===
  final double priceAmount;           // Общая сумма аренды для клиента
  final double commissionAmount;      // Комиссия менеджера/управляющей компании
  final double depositAmount;         // Сумма залога
  final double ownerEarnings;         // Чистая прибыль владельца (priceAmount - commissionAmount)
  
  // === ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ ===
  final int? mileageStart;
  final int? mileageEnd;
  final String? notes; // Дополнительные заметки
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // === ЧАТ ===
  final bool hasUnreadMessages; // Есть ли непрочитанные сообщения
  final DateTime? lastMessageAt; // Время последнего сообщения
  final int messageCount; // Общее количество сообщений

  Rental({
    required this.id,
    required this.carId,
    required this.clientId,
    required this.rentalUserId,
    required this.carOwnerId,
    this.managingCompanyId,
    @Deprecated('Use rentalUserId instead') this.managerId,
    @Deprecated('Use carOwnerId instead') this.organizationId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.priceAmount,
    required this.commissionAmount,
    required this.depositAmount,
    double? ownerEarnings,
    this.mileageStart,
    this.mileageEnd,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.hasUnreadMessages = false,
    this.lastMessageAt,
    this.messageCount = 0,
  }) : ownerEarnings = ownerEarnings ?? (priceAmount - commissionAmount);

  // Получить длительность аренды в днях
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  // Проверить, активна ли аренда сейчас
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return status == RentalStatus.active && 
           now.isAfter(startDate) && 
           now.isBefore(endDate);
  }

  // Проверить, можно ли подтвердить аренду
  bool get canBeConfirmed => status == RentalStatus.pending;

  // Проверить, можно ли активировать аренду
  bool get canBeActivated => status == RentalStatus.confirmed;

  // Проверить, можно ли завершить аренду
  bool get canBeCompleted => status == RentalStatus.active;

  // Создать из Firestore документа
  factory Rental.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Rental(
      id: doc.id,
      carId: data['car_id'] ?? '',
      clientId: data['client_id'] ?? '',
      rentalUserId: data['rental_user_id'] ?? data['manager_id'] ?? '',
      carOwnerId: data['car_owner_id'] ?? data['organization_id'] ?? '',
      managingCompanyId: data['managing_company_id'],
      organizationId: data['organization_id'], // Обратная совместимость
      managerId: data['manager_id'], // Обратная совместимость
      startDate: (data['start_date'] as Timestamp).toDate(),
      endDate: (data['end_date'] as Timestamp).toDate(),
      status: RentalStatus.fromString(data['status'] ?? 'PENDING'),
      priceAmount: (data['price_amount'] ?? data['total_amount'] ?? 0.0).toDouble(),
      commissionAmount: (data['commission_amount'] ?? 0.0).toDouble(),
      depositAmount: (data['deposit_amount'] ?? 0.0).toDouble(),
      ownerEarnings: (data['owner_earnings'])?.toDouble(),
      mileageStart: data['mileage_start']?.toInt(),
      mileageEnd: data['mileage_end']?.toInt(),
      notes: data['notes'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hasUnreadMessages: data['hasUnreadMessages'] ?? false,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      messageCount: data['messageCount'] ?? 0,
    );
  }

  // Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'car_id': carId,
      'client_id': clientId,
      'rental_user_id': rentalUserId,
      'car_owner_id': carOwnerId,
      if (managingCompanyId != null) 'managing_company_id': managingCompanyId,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'status': status.value,
      'price_amount': priceAmount,
      'commission_amount': commissionAmount,
      'deposit_amount': depositAmount,
      'owner_earnings': ownerEarnings,
      if (mileageStart != null) 'mileage_start': mileageStart,
      if (mileageEnd != null) 'mileage_end': mileageEnd,
      if (notes != null) 'notes': notes,
      'hasUnreadMessages': hasUnreadMessages,
      if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      'messageCount': messageCount,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Создать копию с изменениями
  Rental copyWith({
    String? carId,
    String? clientId,
    String? rentalUserId,
    String? carOwnerId,
    String? managingCompanyId,
    DateTime? startDate,
    DateTime? endDate,
    RentalStatus? status,
    double? priceAmount,
    double? commissionAmount,
    double? depositAmount,
    double? ownerEarnings,
    int? mileageStart,
    int? mileageEnd,
    String? notes,
  }) {
    return Rental(
      id: id,
      carId: carId ?? this.carId,
      clientId: clientId ?? this.clientId,
      rentalUserId: rentalUserId ?? this.rentalUserId,
      carOwnerId: carOwnerId ?? this.carOwnerId,
      managingCompanyId: managingCompanyId ?? this.managingCompanyId,
      organizationId: organizationId,
      managerId: managerId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      priceAmount: priceAmount ?? this.priceAmount,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      depositAmount: depositAmount ?? this.depositAmount,
      ownerEarnings: ownerEarnings,
      mileageStart: mileageStart ?? this.mileageStart,
      mileageEnd: mileageEnd ?? this.mileageEnd,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Rental(id: $id, carId: $carId, status: ${status.value}, duration: $durationInDays days)';
  }
}