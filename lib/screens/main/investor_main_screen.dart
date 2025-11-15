import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Главный экран для инвесторов
/// Показывает финансовую статистику и отчеты
class InvestorMainScreen extends StatelessWidget {
  const InvestorMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель инвестора'),
        backgroundColor: Colors.green,
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
              Icons.account_balance,
              size: 80,
              color: Colors.green[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Интерфейс инвестора',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Здесь будет отображаться:\n'
                '• Финансовые показатели\n'
                '• Доходность инвестиций\n'
                '• Статистика по компаниям\n'
                '• Отчеты и аналитика',
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
