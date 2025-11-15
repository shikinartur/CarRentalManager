import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Главный экран для гостей
/// Показывает каталог автомобилей и бронирования
class GuestMainScreen extends StatelessWidget {
  const GuestMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель гостя'),
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
              Icons.person_outline,
              size: 80,
              color: Colors.orange[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Интерфейс гостя',
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
                '• Каталог доступных автомобилей\n'
                '• Бронирование машин\n'
                '• Мои активные аренды\n'
                '• История бронирований',
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
