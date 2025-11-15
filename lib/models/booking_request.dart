import 'package:cloud_firestore/cloud_firestore.dart';

/// Статус заявки на бронирование
enum BookingRequestStatus {
  pending('PENDING'),           // Ожидает подтверждения менеджером/директором
  approved('APPROVED'),         // Подтверждена менеджером/директором, ждет финального выбора агента
  confirmed('CONFIRMED'),       // Финально выбрана агентом → создана бронь
  rejected('REJECTED'),         // Отклонена менеджером/директором
  cancelled('CANCELLED'),       // Отменена агентом
  autoAnnulled('AUTO_ANNULLED');// Автоматически аннулирована (агент выбрал другую заявку)

  const BookingRequestStatus(this.value);
  final String value;

  static BookingRequestStatus fromString(String value) {
    return BookingRequestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BookingRequestStatus.pending,
    );
  }

  String get description {
    switch (this) {
      case BookingRequestStatus.pending:
        return 'Ожидает подтверждения';
      case BookingRequestStatus.approved:
        return 'Подтверждена, ожидает выбора';
      case BookingRequestStatus.confirmed:
        return 'Выбрана и забронирована';
      case BookingRequestStatus.rejected:
        return 'Отклонена';
      case BookingRequestStatus.cancelled:
        return 'Отменена';
      case BookingRequestStatus.autoAnnulled:
        return 'Аннулирована автоматически';
    }
  }
}

/// Заявка на бронирование (создается агентами)
/// 
/// Workflow:
/// 1. Агент создает несколько заявок на разные машины (status: PENDING)
/// 2. Менеджер/директор подтверждает заявки (status: APPROVED)
/// 3. Агент выбирает одну из подтвержденных (status: CONFIRMED → создается Rental)
/// 4. Остальные подтвержденные заявки автоматически аннулируются (status: AUTO_ANNULLED)
/// 5. Машины снова становятся доступными
class BookingRequest {
  final String id;
  
  // === ОСНОВНАЯ ИНФОРМАЦИЯ ===
  final String carId;
  final String clientId;
  final String createdBy;        // ID агента, создавшего заявку
  final String? companyId;       // Компания, в контексте которой создана заявка
  final String requestGroupId;   // ID группы связанных заявок (одна сессия поиска)
  
  // === ДАТЫ И СТАТУС ===
  final DateTime startDate;
  final DateTime endDate;
  final BookingRequestStatus status;
  
  // === ФИНАНСЫ (предложенные агентом) ===
  final double proposedPrice;    // Предложенная цена для клиента
  final double proposedDeposit;  // Предложенный залог
  
  // === ПОДТВЕРЖДЕНИЕ/ОТКЛОНЕНИЕ ===
  final String? reviewedBy;      // Кто рассмотрел заявку (менеджер/директор)
  final DateTime? reviewedAt;    // Когда рассмотрена
  final String? reviewNote;      // Комментарий при рассмотрении
  
  // === ФИНАЛЬНОЕ ПОДТВЕРЖДЕНИЕ АГЕНТОМ ===
  final String? confirmedBy;     // Кто финально подтвердил (должен быть createdBy)
  final DateTime? confirmedAt;   // Когда агент выбрал эту заявку
  final String? rentalId;        // ID созданного бронирования (если confirmed)
  
  // === АННУЛЯЦИЯ ===
  final String? annulledBy;      // ID заявки, которая была выбрана вместо этой
  final DateTime? annulledAt;    // Когда аннулирована
  
  // === ДОПОЛНИТЕЛЬНО ===
  final String? notes;           // Заметки агента
  final DateTime createdAt;
  final DateTime updatedAt;

  BookingRequest({
    required this.id,
    required this.carId,
    required this.clientId,
    required this.createdBy,
    this.companyId,
    required this.requestGroupId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.proposedPrice,
    required this.proposedDeposit,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    this.confirmedBy,
    this.confirmedAt,
    this.rentalId,
    this.annulledBy,
    this.annulledAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Создать из Firestore документа
  factory BookingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return BookingRequest(
      id: doc.id,
      carId: data['car_id'] ?? '',
      clientId: data['client_id'] ?? '',
      createdBy: data['created_by'] ?? '',
      companyId: data['company_id'],
      requestGroupId: data['request_group_id'] ?? doc.id, // Fallback для старых данных
      startDate: (data['start_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['end_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: BookingRequestStatus.fromString(data['status'] ?? 'PENDING'),
      proposedPrice: (data['proposed_price'] ?? 0).toDouble(),
      proposedDeposit: (data['proposed_deposit'] ?? 0).toDouble(),
      reviewedBy: data['reviewed_by'],
      reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate(),
      reviewNote: data['review_note'],
      confirmedBy: data['confirmed_by'],
      confirmedAt: (data['confirmed_at'] as Timestamp?)?.toDate(),
      rentalId: data['rental_id'],
      annulledBy: data['annulled_by'],
      annulledAt: (data['annulled_at'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'car_id': carId,
      'client_id': clientId,
      'created_by': createdBy,
      if (companyId != null) 'company_id': companyId,
      'request_group_id': requestGroupId,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'status': status.value,
      'proposed_price': proposedPrice,
      'proposed_deposit': proposedDeposit,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': Timestamp.fromDate(reviewedAt!),
      if (reviewNote != null) 'review_note': reviewNote,
      if (confirmedBy != null) 'confirmed_by': confirmedBy,
      if (confirmedAt != null) 'confirmed_at': Timestamp.fromDate(confirmedAt!),
      if (rentalId != null) 'rental_id': rentalId,
      if (annulledBy != null) 'annulled_by': annulledBy,
      if (annulledAt != null) 'annulled_at': Timestamp.fromDate(annulledAt!),
      if (notes != null) 'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  /// Проверить, ожидает ли заявка рассмотрения
  bool get isPending => status == BookingRequestStatus.pending;

  /// Проверить, подтверждена ли заявка (ждет выбора агента)
  bool get isApproved => status == BookingRequestStatus.approved;

  /// Проверить, финально подтверждена ли заявка (выбрана агентом)
  bool get isConfirmed => status == BookingRequestStatus.confirmed;

  /// Проверить, отклонена ли заявка
  bool get isRejected => status == BookingRequestStatus.rejected;

  /// Проверить, аннулирована ли заявка
  bool get isAnnulled => status == BookingRequestStatus.autoAnnulled;

  /// Создать копию с изменениями
  BookingRequest copyWith({
    BookingRequestStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNote,
    String? confirmedBy,
    DateTime? confirmedAt,
    String? rentalId,
    String? annulledBy,
    DateTime? annulledAt,
    DateTime? updatedAt,
  }) {
    return BookingRequest(
      id: id,
      carId: carId,
      clientId: clientId,
      createdBy: createdBy,
      companyId: companyId,
      requestGroupId: requestGroupId,
      startDate: startDate,
      endDate: endDate,
      status: status ?? this.status,
      proposedPrice: proposedPrice,
      proposedDeposit: proposedDeposit,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rentalId: rentalId ?? this.rentalId,
      annulledBy: annulledBy ?? this.annulledBy,
      annulledAt: annulledAt ?? this.annulledAt,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BookingRequest(id: $id, group: $requestGroupId, car: $carId, client: $clientId, status: ${status.value}, createdBy: $createdBy)';
  }
}
