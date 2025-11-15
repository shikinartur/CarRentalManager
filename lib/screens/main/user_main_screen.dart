import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_role_service.dart';
import '../../services/interface_service.dart';
import '../../models/user_role.dart';
import '../auth/role_selection_screen.dart';

/// Главный экран для прокатчиков (директора, менеджеры)
/// Показывает управление компанией, автопарком и бронированиями
/// 
/// ВАЖНО: Для доступа к этому интерфейсу пользователь должен иметь
/// хотя бы одну активную роль (OWNER, DIRECTOR, MANAGER) 
/// привязанную к компании
class RentalMainScreen extends StatefulWidget {
  const RentalMainScreen({super.key});

  @override
  State<RentalMainScreen> createState() => _RentalMainScreenState();
}

class _RentalMainScreenState extends State<RentalMainScreen> {
  final _userRoleService = UserRoleService();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _hasAccess = false;
  List<UserRole> _userRoles = [];

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  /// Проверить доступ пользователя к интерфейсу
  Future<void> _checkAccess() async {
    try {
      final firebaseUser = _authService.currentFirebaseUser;
      if (firebaseUser == null) {
        setState(() {
          _isLoading = false;
          _hasAccess = false;
        });
        return;
      }

      // Получаем все роли пользователя
      final roles = await _userRoleService.getUserRoles(firebaseUser.uid);
      
      // Фильтруем только роли прокатчиков (привязанные к компании)
      final relevantRoles = roles.where((role) =>
        (role.roleType == RoleType.owner ||
         role.roleType == RoleType.director ||
         role.roleType == RoleType.manager) &&
        role.companyId != null  // Обязательно должна быть привязка к компании
      ).toList();

      setState(() {
        _userRoles = relevantRoles;
        _hasAccess = relevantRoles.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking access: $e');
      setState(() {
        _isLoading = false;
        _hasAccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Проверка доступа...'),
            ],
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return _buildNoAccessScreen();
    }

    return _buildMainScreen();
  }

  /// Экран при отсутствии доступа
  Widget _buildNoAccessScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Доступ запрещен'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _signOut,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  'Нет доступа к интерфейсу',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Для доступа к интерфейсу прокатчика вы должны быть привязаны к компании в роли:',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRoleItem('Владелец', 'Полный контроль над компанией'),
                        const Divider(),
                        _buildRoleItem('Директор', 'Управление операциями компании'),
                        const Divider(),
                        _buildRoleItem('Менеджер', 'Обработка бронирований в компании'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'У вас нет привязки к компании. Попробуйте войти как:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _switchInterface(InterfaceType.agent),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Агент'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _switchInterface(InterfaceType.investor),
                      icon: const Icon(Icons.account_balance),
                      label: const Text('Инвестор'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _signOut,
                  child: const Text('Выйти из системы'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Основной экран с доступом
  Widget _buildMainScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель управления'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _signOut,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center,
              size: 80,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 24),
            Text(
              'Интерфейс пользователя',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Здесь будет отображаться:\n'
                '• Управление компанией/гаражом\n'
                '• Автопарк и автомобили\n'
                '• Бронирования и заявки\n'
                '• Клиенты и команда\n'
                '• Финансовые операции',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            if (_userRoles.isNotEmpty) ...[
              Text(
                'Ваши активные роли:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...(_userRoles.take(5).map((role) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Chip(
                  avatar: Icon(
                    _getRoleIcon(role.roleType),
                    size: 18,
                  ),
                  label: Text(
                    '${_getRoleTitle(role.roleType)} в ${role.companyId ?? role.garageId}',
                  ),
                ),
              ))),
              if (_userRoles.length > 5)
                Text(
                  'И еще ${_userRoles.length - 5} роли...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getRoleIcon(RoleType role) {
    switch (role) {
      case RoleType.owner:
        return Icons.star;
      case RoleType.director:
        return Icons.business_center;
      case RoleType.manager:
        return Icons.manage_accounts;
      case RoleType.agent:
        return Icons.support_agent;
      case RoleType.guest:
        return Icons.person_outline;
    }
  }

  String _getRoleTitle(RoleType role) {
    switch (role) {
      case RoleType.owner:
        return 'Владелец';
      case RoleType.director:
        return 'Директор';
      case RoleType.manager:
        return 'Менеджер';
      case RoleType.agent:
        return 'Агент';
      case RoleType.guest:
        return 'Гость';
    }
  }

  /// Переключиться на другой интерфейс
  Future<void> _switchInterface(InterfaceType newType) async {
    await InterfaceService().saveInterfaceType(newType);
    if (mounted) {
      // Перезагружаем приложение через Navigator
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }
}
