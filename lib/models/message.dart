import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';

class Message {
  final String id;
  final String rentalId; // ID бронирования, к которому привязано сообщение
  final String senderId; // ID отправителя
  final String senderName; // Имя отправителя для отображения
  final GlobalRole senderRole; // Роль отправителя
  final String text; // Текст сообщения
  final DateTime timestamp; // Время отправки
  final bool isRead; // Прочитано ли сообщение

  Message({
    required this.id,
    required this.rentalId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  // Создание из Firestore документа
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      rentalId: data['rentalId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: GlobalRole.values.firstWhere(
        (e) => e.toString() == 'GlobalRole.${data['senderRole']}',
        orElse: () => GlobalRole.manager,
      ),
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  // Преобразование в Map для Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'rentalId': rentalId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  // Копирование с изменениями
  Message copyWith({
    String? id,
    String? rentalId,
    String? senderId,
    String? senderName,
    GlobalRole? senderRole,
    String? text,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      rentalId: rentalId ?? this.rentalId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
