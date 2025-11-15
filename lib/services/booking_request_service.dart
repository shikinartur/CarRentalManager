import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:car_rental_manager/models/models.dart';

/// Сервис для работы с заявками на бронирование
class BookingRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Создать группу заявок для нескольких машин
  Future<List<String>> createMultipleRequests({
    required List<String> carIds,
    required String clientId,
    required String createdBy,
    required String? companyId,
    required DateTime startDate,
    required DateTime endDate,
    required double proposedPrice,
    required double proposedDeposit,
    String? notes,
  }) async {
    // Сгенерировать общий ID для группы заявок
    final requestGroupId = _firestore.collection('booking_requests').doc().id;
    final requestIds = <String>[];
    
    final batch = _firestore.batch();
    
    for (final carId in carIds) {
      final requestId = _firestore.collection('booking_requests').doc().id;
      
      final request = BookingRequest(
        id: requestId,
        carId: carId,
        clientId: clientId,
        createdBy: createdBy,
        companyId: companyId,
        requestGroupId: requestGroupId,
        startDate: startDate,
        endDate: endDate,
        status: BookingRequestStatus.pending,
        proposedPrice: proposedPrice,
        proposedDeposit: proposedDeposit,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      batch.set(
        _firestore.collection('booking_requests').doc(requestId),
        request.toFirestore(),
      );
      
      requestIds.add(requestId);
    }
    
    await batch.commit();
    
    return requestIds;
  }

  /// Получить все заявки из группы
  Future<List<BookingRequest>> getRequestsByGroupId(String groupId) async {
    final snapshot = await _firestore
        .collection('booking_requests')
        .where('request_group_id', isEqualTo: groupId)
        .get();
    
    return snapshot.docs
        .map((doc) => BookingRequest.fromFirestore(doc))
        .toList();
  }

  /// Получить подтвержденные заявки из группы
  Future<List<BookingRequest>> getApprovedRequestsByGroupId(String groupId) async {
    final snapshot = await _firestore
        .collection('booking_requests')
        .where('request_group_id', isEqualTo: groupId)
        .where('status', isEqualTo: BookingRequestStatus.approved.value)
        .get();
    
    return snapshot.docs
        .map((doc) => BookingRequest.fromFirestore(doc))
        .toList();
  }

  /// Подтвердить заявку (менеджер/директор)
  Future<void> approveRequest({
    required String requestId,
    required String reviewedBy,
    String? reviewNote,
  }) async {
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': BookingRequestStatus.approved.value,
      'reviewed_by': reviewedBy,
      'reviewed_at': FieldValue.serverTimestamp(),
      'review_note': reviewNote,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Финально подтвердить заявку (агент выбирает) → создает бронь и аннулирует остальные
  Future<void> confirmRequestByAgent({
    required String requestId,
    required String confirmedBy,
    required String rentalId,
  }) async {
    final request = await getRequestById(requestId);
    
    // Обновить выбранную заявку
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': BookingRequestStatus.confirmed.value,
      'confirmed_by': confirmedBy,
      'confirmed_at': FieldValue.serverTimestamp(),
      'rental_id': rentalId,
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    // Аннулировать все остальные заявки из группы
    await _annulOtherRequestsInGroup(
      requestGroupId: request.requestGroupId,
      excludeRequestId: requestId,
      selectedRequestId: requestId,
    );
  }

  /// Отклонить заявку
  Future<void> rejectRequest({
    required String requestId,
    required String reviewedBy,
    required String reason,
  }) async {
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': BookingRequestStatus.rejected.value,
      'reviewed_by': reviewedBy,
      'reviewed_at': FieldValue.serverTimestamp(),
      'review_note': reason,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Отменить заявку (агент)
  Future<void> cancelRequest(String requestId) async {
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': BookingRequestStatus.cancelled.value,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Получить заявку по ID
  Future<BookingRequest> getRequestById(String requestId) async {
    final doc = await _firestore
        .collection('booking_requests')
        .doc(requestId)
        .get();
    
    if (!doc.exists) {
      throw Exception('Заявка не найдена');
    }
    
    return BookingRequest.fromFirestore(doc);
  }

  /// Получить заявки агента
  Future<List<BookingRequest>> getRequestsByAgent(String agentId) async {
    final snapshot = await _firestore
        .collection('booking_requests')
        .where('created_by', isEqualTo: agentId)
        .orderBy('created_at', descending: true)
        .get();
    
    return snapshot.docs
        .map((doc) => BookingRequest.fromFirestore(doc))
        .toList();
  }

  /// Получить ожидающие заявки компании
  Future<List<BookingRequest>> getPendingRequestsByCompany(String companyId) async {
    final snapshot = await _firestore
        .collection('booking_requests')
        .where('company_id', isEqualTo: companyId)
        .where('status', isEqualTo: BookingRequestStatus.pending.value)
        .orderBy('created_at', descending: true)
        .get();
    
    return snapshot.docs
        .map((doc) => BookingRequest.fromFirestore(doc))
        .toList();
  }

  /// Stream ожидающих заявок компании
  Stream<List<BookingRequest>> watchPendingRequestsByCompany(String companyId) {
    return _firestore
        .collection('booking_requests')
        .where('company_id', isEqualTo: companyId)
        .where('status', isEqualTo: BookingRequestStatus.pending.value)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingRequest.fromFirestore(doc))
            .toList());
  }

  /// Аннулировать все остальные заявки из группы (приватный метод)
  Future<void> _annulOtherRequestsInGroup({
    required String requestGroupId,
    required String excludeRequestId,
    required String selectedRequestId,
  }) async {
    final snapshot = await _firestore
        .collection('booking_requests')
        .where('request_group_id', isEqualTo: requestGroupId)
        .get();
    
    final batch = _firestore.batch();
    
    for (final doc in snapshot.docs) {
      if (doc.id == excludeRequestId) continue;
      
      final request = BookingRequest.fromFirestore(doc);
      
      // Аннулировать только PENDING и APPROVED заявки
      if (request.status == BookingRequestStatus.pending ||
          request.status == BookingRequestStatus.approved) {
        
        batch.update(doc.reference, {
          'status': BookingRequestStatus.autoAnnulled.value,
          'annulled_by': selectedRequestId,
          'annulled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
    
    await batch.commit();
  }
}
