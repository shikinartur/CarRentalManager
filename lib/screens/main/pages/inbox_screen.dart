import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/rental.dart';
import '../../../models/user.dart';
import '../../../services/services.dart';
import '../../rental/rental_chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _currentUserName = '';
  GlobalRole _currentUserRole = GlobalRole.manager;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = _authService.currentFirebaseUser;
    if (user != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        setState(() {
          _currentUserName = user.displayName ?? 'Пользователь';
          _currentUserRole = GlobalRole.values.firstWhere(
            (e) => e.name == data['globalRole'],
            orElse: () => GlobalRole.manager,
          );
        });
      }
    }
  }

  void _openChat(Rental rental) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalChatScreen(
          rental: rental,
          currentUserName: _currentUserName,
          currentUserRole: _currentUserRole,
        ),
      ),
    );
  }

  Future<void> _rejectWithMessage(Rental rental) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отклонить заявку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Укажите причину отклонения:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Например: Не хватает залога',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await _chatService.rejectWithMessage(
          rentalId: rental.id,
          reason: reasonController.text.trim(),
          senderName: _currentUserName,
          senderRole: _currentUserRole,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Заявка отклонена, сообщение отправлено'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Входящие заявки'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<List<Rental>>(
        stream: _firestore
            .collection('rentals')
            .where('status', isEqualTo: 'PENDING')
            .snapshots()
            .map((snapshot) =>
                snapshot.docs.map((doc) => Rental.fromFirestore(doc)).toList()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final rentals = snapshot.data ?? [];

          if (rentals.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Нет входящих заявок',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rentals.length,
            itemBuilder: (context, index) {
              final rental = rentals[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.pending, color: Colors.white),
                  ),
                  title: Row(
                    children: [
                      Text('Бронь #${rental.id.substring(0, 8)}'),
                      const SizedBox(width: 8),
                      if (rental.hasUnreadMessages)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${rental.messageCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Залог: ${rental.depositAmount}₽\n'
                    'Период: ${rental.startDate.day}.${rental.startDate.month} - ${rental.endDate.day}.${rental.endDate.month}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'chat',
                        child: Row(
                          children: [
                            Icon(Icons.chat),
                            SizedBox(width: 8),
                            Text('Открыть чат'),
                          ],
                        ),
                      ),
                      if (_currentUserRole == GlobalRole.director)
                        const PopupMenuItem(
                          value: 'reject',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Отклонить с сообщением'),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) {
                      if (value == 'chat') {
                        _openChat(rental);
                      } else if (value == 'reject') {
                        _rejectWithMessage(rental);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Для тестирования создайте бронирование через Firebase Console'),
            ),
          );
        },
        icon: const Icon(Icons.info_outline),
        label: const Text('Как тестировать'),
      ),
    );
  }
}
