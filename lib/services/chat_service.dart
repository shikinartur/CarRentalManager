import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'auth_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Отправить сообщение в чат бронирования
  Future<void> sendMessage({
    required String rentalId,
    required String text,
    required String senderName,
    required GlobalRole senderRole,
  }) async {
    final currentUser = _authService.currentFirebaseUser;
    if (currentUser == null) {
      throw Exception('Пользователь не авторизован');
    }

    if (text.trim().isEmpty) {
      throw Exception('Сообщение не может быть пустым');
    }

    final message = Message(
      id: '', // ID будет назначен Firestore
      rentalId: rentalId,
      senderId: currentUser.uid,
      senderName: senderName,
      senderRole: senderRole,
      text: text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
    );

    // Сохраняем сообщение в под-коллекцию messages бронирования
    await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('messages')
        .add(message.toFirestore());

    // Обновляем метаданные бронирования
    await _firestore.collection('rentals').doc(rentalId).update({
      'hasUnreadMessages': true,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
    });
  }

  // Получить поток сообщений для бронирования
  Stream<List<Message>> getMessages(String rentalId) {
    return _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // Сортировка от старых к новым
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  // Получить количество непрочитанных сообщений для бронирования
  Future<int> getUnreadCount(String rentalId, String userId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId) // Не считаем свои сообщения
        .get();

    return snapshot.docs.length;
  }

  // Отметить все сообщения как прочитанные для текущего пользователя
  Future<void> markAllAsRead(String rentalId) async {
    final currentUser = _authService.currentFirebaseUser;
    if (currentUser == null) return;

    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUser.uid)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Обновляем метаданные бронирования
    batch.update(_firestore.collection('rentals').doc(rentalId), {
      'hasUnreadMessages': false,
    });

    await batch.commit();
  }

  // Удалить все сообщения бронирования (для admin)
  Future<void> deleteAllMessages(String rentalId) async {
    final snapshot = await _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    // Сбрасываем метаданные
    batch.update(_firestore.collection('rentals').doc(rentalId), {
      'hasUnreadMessages': false,
      'lastMessageAt': null,
      'messageCount': 0,
    });

    await batch.commit();
  }

  // Отклонить заявку и отправить сообщение (для DIRECTOR)
  Future<void> rejectWithMessage({
    required String rentalId,
    required String reason,
    required String senderName,
    required GlobalRole senderRole,
  }) async {
    final batch = _firestore.batch();

    // Обновляем статус бронирования
    batch.update(_firestore.collection('rentals').doc(rentalId), {
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': _authService.currentFirebaseUser?.uid,
    });

    // Добавляем сообщение с причиной отклонения
    final messageRef = _firestore
        .collection('rentals')
        .doc(rentalId)
        .collection('messages')
        .doc();

    final message = Message(
      id: messageRef.id,
      rentalId: rentalId,
      senderId: _authService.currentFirebaseUser!.uid,
      senderName: senderName,
      senderRole: senderRole,
      text: '❌ Заявка отклонена. Причина: $reason',
      timestamp: DateTime.now(),
      isRead: false,
    );

    batch.set(messageRef, message.toFirestore());

    // Обновляем метаданные
    batch.update(_firestore.collection('rentals').doc(rentalId), {
      'hasUnreadMessages': true,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
    });

    await batch.commit();
  }
}
