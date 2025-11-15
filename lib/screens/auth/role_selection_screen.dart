import 'package:flutter/material.dart';
import 'login_screen.dart';

/// Типы интерфейсов в системе
enum InterfaceType {
  investor,  // Интерфейс для инвесторов
  rental,    // Интерфейс для прокатчиков (директора, менеджеры)
  agent,     // Интерфейс для агентов
}

/// Экран выбора типа интерфейса перед входом
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип и заголовок
                  Icon(
                    Icons.car_rental,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Car Rental Manager',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Выберите тип входа',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Карточки выбора интерфейса
                  _InterfaceCard(
                    icon: Icons.account_balance,
                    title: 'Инвестор',
                    description: 'Просмотр статистики и финансовых показателей',
                    color: Colors.green,
                    interfaceType: InterfaceType.investor,
                  ),
                  const SizedBox(height: 16),
                  
                  _InterfaceCard(
                    icon: Icons.car_rental,
                    title: 'Прокатчик',
                    description: 'Управление компанией, автопарком и бронированиями',
                    color: Colors.blue,
                    interfaceType: InterfaceType.rental,
                  ),
                  const SizedBox(height: 16),
                  
                  _InterfaceCard(
                    icon: Icons.support_agent,
                    title: 'Агент',
                    description: 'Создание заявок на бронирование',
                    color: Colors.orange,
                    interfaceType: InterfaceType.agent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка выбора типа интерфейса
class _InterfaceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final InterfaceType interfaceType;

  const _InterfaceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.interfaceType,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(interfaceType: interfaceType),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
