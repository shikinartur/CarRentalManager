import 'package:cloud_firestore/cloud_firestore.dart';

/// Права доступа конкретного пользователя к конкретному автомобилю
/// Используется для гранулярного управления доступом менеджеров к автомобилям
/// 
/// Типы прав:
/// - canView: просмотр загрузки автомобиля (может выдать владелец гаража/компании)
/// - canEditCar: редактирование данных автомобиля (марка, модель, характеристики, фото, тарифы)
///   НЕ включает: удаление авто, изменение статуса доступности (статус вычисляется автоматически)
/// - canBook: создание бронирований напрямую (без подтверждения)
/// - canOrder: создание заявок (требуют подтверждения для перевода в бронь)
/// - canConfirm: подтверждение заявок других пользователей
/// - canHandover: выдача и приемка автомобиля (начало и завершение аренды)
/// 
/// Примечание: 
/// - Менеджеры могут редактировать СВОИ заявки и бронирования
/// - Менеджеры отличаются только набором прав на конкретные автомобили
/// - Добавление и удаление автомобилей - это отдельные права владельца/DIRECTOR
class CarPermissions {
  final String userId;
  final String carId;
  final bool canView;     // Просмотр загрузки автомобиля
  final bool canEditCar;  // Редактирование данных (БЕЗ удаления)
  final bool canBook;     // Создание бронирований (без подтверждения)
  final bool canOrder;    // Создание заявок (требуют подтверждения)
  final bool canConfirm;  // Подтверждение заявок других
  final bool canHandover; // Выдача и приемка авто
  final DateTime grantedAt;
  final String grantedBy; // ID пользователя, выдавшего права

  CarPermissions({
    required this.userId,
    required this.carId,
    this.canView = true,
    this.canEditCar = false,
    this.canBook = false,
    this.canOrder = false,
    this.canConfirm = false,
    this.canHandover = false,
    required this.grantedAt,
    required this.grantedBy,
  });

  /// Проверить, есть ли хотя бы одно право
  bool get hasAnyPermission => canView || canEditCar || canBook || canOrder || canConfirm || canHandover;

  /// Проверить, есть ли полные права (все разрешения)
  bool get hasFullAccess => canView && canEditCar && canBook && canOrder && canConfirm && canHandover;

  /// Создать права только для просмотра
  factory CarPermissions.viewOnly({
    required String userId,
    required String carId,
    required String grantedBy,
  }) {
    return CarPermissions(
      userId: userId,
      carId: carId,
      canView: true,
      grantedAt: DateTime.now(),
      grantedBy: grantedBy,
    );
  }

  /// Создать полные права доступа
  factory CarPermissions.fullAccess({
    required String userId,
    required String carId,
    required String grantedBy,
  }) {
    return CarPermissions(
      userId: userId,
      carId: carId,
      canView: true,
      canEditCar: true,
      canBook: true,
      canOrder: true,
      canConfirm: true,
      canHandover: true,
      grantedAt: DateTime.now(),
      grantedBy: grantedBy,
    );
  }

  /// Создать из Firestore документа
  factory CarPermissions.fromFirestore(Map<String, dynamic> data) {
    return CarPermissions(
      userId: data['user_id'] ?? '',
      carId: data['car_id'] ?? '',
      canView: data['can_view'] ?? true,
      canEditCar: data['can_edit_car'] ?? false,
      canBook: data['can_book'] ?? false,
      canOrder: data['can_order'] ?? false,
      canConfirm: data['can_confirm'] ?? false,
      canHandover: data['can_handover'] ?? false,
      grantedAt: (data['granted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      grantedBy: data['granted_by'] ?? '',
    );
  }

  /// Конвертировать в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'car_id': carId,
      'can_view': canView,
      'can_edit_car': canEditCar,
      'can_book': canBook,
      'can_order': canOrder,
      'can_confirm': canConfirm,
      'can_handover': canHandover,
      'granted_at': Timestamp.fromDate(grantedAt),
      'granted_by': grantedBy,
    };
  }

  /// Создать копию с изменениями
  CarPermissions copyWith({
    bool? canView,
    bool? canEditCar,
    bool? canBook,
    bool? canOrder,
    bool? canConfirm,
    bool? canHandover,
  }) {
    return CarPermissions(
      userId: userId,
      carId: carId,
      canView: canView ?? this.canView,
      canEditCar: canEditCar ?? this.canEditCar,
      canBook: canBook ?? this.canBook,
      canOrder: canOrder ?? this.canOrder,
      canConfirm: canConfirm ?? this.canConfirm,
      canHandover: canHandover ?? this.canHandover,
      grantedAt: grantedAt,
      grantedBy: grantedBy,
    );
  }

  @override
  String toString() {
    return 'CarPermissions(userId: $userId, carId: $carId, view: $canView, editCar: $canEditCar, book: $canBook, order: $canOrder, confirm: $canConfirm, handover: $canHandover)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CarPermissions &&
        other.userId == userId &&
        other.carId == carId;
  }

  @override
  int get hashCode => Object.hash(userId, carId);
}
