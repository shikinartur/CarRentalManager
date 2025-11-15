import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../models/rental.dart';
import '../../models/user.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';

class RentalChatScreen extends StatefulWidget {
  final Rental rental;
  final String currentUserName;
  final GlobalRole currentUserRole;

  const RentalChatScreen({
    super.key,
    required this.rental,
    required this.currentUserName,
    required this.currentUserRole,
  });

  @override
  State<RentalChatScreen> createState() => _RentalChatScreenState();
}

class _RentalChatScreenState extends State<RentalChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Отметить все сообщения как прочитанные при открытии
    _chatService.markAllAsRead(widget.rental.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        rentalId: widget.rental.id,
        text: _messageController.text.trim(),
        senderName: widget.currentUserName,
        senderRole: widget.currentUserRole,
      );

      _messageController.clear();
      
      // Прокрутить вниз после отправки
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Вчера ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp);
    }
  }

  Color _getRoleColor(GlobalRole role) {
    switch (role) {
      case GlobalRole.director:
        return Colors.purple.shade700;
      case GlobalRole.manager:
        return Colors.blue.shade700;
      case GlobalRole.investor:
        return Colors.green.shade700;
      case GlobalRole.guest:
        return Colors.grey.shade700;
    }
  }

  String _getRoleName(GlobalRole role) {
    switch (role) {
      case GlobalRole.director:
        return 'Директор';
      case GlobalRole.manager:
        return 'Менеджер';
      case GlobalRole.investor:
        return 'Владелец';
      case GlobalRole.guest:
        return 'Гость';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentFirebaseUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Чат по бронированию'),
            Text(
              'Бронь #${widget.rental.id.substring(0, 8)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Список сообщений
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessages(widget.rental.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Нет сообщений',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Начните общение',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Автопрокрутка вниз при первой загрузке
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isCurrentUser = message.senderId == currentUserId;

                    return Align(
                      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Имя отправителя и роль
                            Row(
                              children: [
                                Text(
                                  message.senderName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(message.senderRole),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getRoleName(message.senderRole),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Текст сообщения
                            Text(
                              message.text,
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            // Время отправки
                            Text(
                              _formatTimestamp(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Поле ввода сообщения
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send, color: Colors.blue),
                        iconSize: 28,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

