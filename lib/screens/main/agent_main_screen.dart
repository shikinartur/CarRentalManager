import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Главный экран для агентов
/// Показывает создание заявок на бронирование
class AgentMainScreen extends StatelessWidget {
  const AgentMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель агента'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _signOut(context),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent,
              size: 80,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Интерфейс агента',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Здесь будет отображаться:\n'
                '• Создание заявок на бронирование\n'
                '• Мои активные заявки\n'
                '• Статусы заявок\n'
                '• История заявок\n'
                '• Клиенты',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
  }
}
