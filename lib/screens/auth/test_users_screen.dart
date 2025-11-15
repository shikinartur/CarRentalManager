import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/test_user_service.dart';
import '../../models/user_role.dart';

class TestUsersScreen extends StatefulWidget {
  const TestUsersScreen({super.key});

  @override
  State<TestUsersScreen> createState() => _TestUsersScreenState();
}

class _TestUsersScreenState extends State<TestUsersScreen> {
  final _testUserService = TestUserService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Проверка валидности email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите корректный email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Проверка длины пароля
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль должен содержать минимум 6 символов'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _testUserService.createTestUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пользователь создан'),
          backgroundColor: Colors.green,
        ),
      );

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'Ошибка создания пользователя';
      
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'Этот email уже используется другим пользователем';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Неверный формат email';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Пароль слишком простой (минимум 6 символов)';
      } else if (e.toString().contains('network-request-failed')) {
        errorMessage = 'Ошибка сети. Проверьте подключение к интернету';
      } else {
        errorMessage = 'Ошибка: ${e.toString().replaceAll('Exception: Ошибка создания пользователя: ', '')}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteUser(String userId, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('Удалить "$displayName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _testUserService.deleteTestUser(userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пользователь удалён'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _quickLogin(String email, String password) async {
    try {
      await _testUserService.quickLogin(email: email, password: password);

      if (!mounted) return;

      Navigator.pop(context); // Закрыть экран тестовых пользователей
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка входа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getRoleColor(RoleType role) {
    switch (role) {
      case RoleType.owner:
        return Colors.purple;
      case RoleType.director:
        return Colors.blue;
      case RoleType.manager:
        return Colors.green;
      case RoleType.agent:
        return Colors.orange;
      case RoleType.guest:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return formatter.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тестовые пользователи'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Удалить всех тестовых пользователей',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Удалить всех?'),
                  content: const Text(
                    'Удалить всех тестовых пользователей из базы данных?\n\n'
                    '⚠️ ВАЖНО: Пользователи будут удалены из списка, но их email '
                    'останутся занятыми в системе аутентификации Firebase. '
                    'Используйте разные email для каждого нового теста.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Понятно, удалить'),
                    ),
                  ],
                ),
              );

              if (confirm != true || !mounted) return;

              // Показываем индикатор загрузки
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Удаление пользователей...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              try {
                await _testUserService.deleteAllTestUsers();
                if (!mounted) return;
                
                Navigator.pop(context); // Закрыть диалог загрузки
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Все тестовые пользователи удалены'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                
                Navigator.pop(context); // Закрыть диалог загрузки
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка удаления: ${e.toString().replaceAll('Exception: ', '')}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Левая панель - создание пользователя
          Expanded(
            flex: 2,
            child: Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Создать нового пользователя',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Имя',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.auto_fix_high),
                            tooltip: 'Сгенерировать уникальный email',
                            onPressed: () {
                              final timestamp = DateTime.now().millisecondsSinceEpoch;
                              final randomEmail = 'test_${timestamp}@test.com';
                              _emailController.text = randomEmail;
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isCreating ? null : _createUser,
                          icon: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(_isCreating ? 'Создание...' : 'Создать пользователя'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isCreating ? null : () async {
                            final timestamp = DateTime.now().millisecondsSinceEpoch;
                            _nameController.text = 'Тест $timestamp';
                            _emailController.text = 'test_${timestamp}@test.com';
                            _passwordController.text = 'test123';
                            await _createUser();
                          },
                          icon: const Icon(Icons.flash_on),
                          label: const Text('Быстрое создание'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[700],
                            side: BorderSide(color: Colors.blue[700]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Информация',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Новый пользователь будет создан с ролью "Гость". '
                              'Роль будет меняться автоматически при работе в приложении.\n\n'
                              '⚠️ Используйте уникальный email, который не занят другим пользователем. '
                              'Нажмите на иконку ✨ справа от поля Email для автоматической генерации уникального адреса.\n\n'
                              '⚠️ Примечание: Firebase Auth не позволяет удалять пользователей программно. '
                              'Email останется занятым даже после удаления из списка. Используйте разные email для каждого теста.',
                              style: TextStyle(color: Colors.blue[900], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Правая панель - список пользователей
          Expanded(
            flex: 3,
            child: Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Существующие пользователи',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<List<UserWithRoles>>(
                      stream: _testUserService.getAllTestUsers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Ошибка: ${snapshot.error}'),
                          );
                        }

                        final users = snapshot.data ?? [];

                        if (users.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Нет тестовых пользователей',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final userWithRoles = users[index];
                            final user = userWithRoles.user;
                            final roles = userWithRoles.roles;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Заголовок с аватаром и именем
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: _getRoleColor(userWithRoles.primaryRole),
                                          radius: 24,
                                          child: Text(
                                            user.displayName.isNotEmpty
                                                ? user.displayName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                user.email,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.login, size: 18),
                                          label: const Text('Войти'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[700],
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: userWithRoles.testPassword != null
                                              ? () => _quickLogin(user.email, userWithRoles.testPassword!)
                                              : null,
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    
                                    // Роли
                                    _buildInfoRow(
                                      'Роли',
                                      roles.isEmpty
                                          ? 'Гость'
                                          : roles.map((r) {
                                              String roleDesc = r.roleType.description;
                                              if (r.companyId != null && userWithRoles.companyNames.containsKey(r.companyId)) {
                                                roleDesc += ' (${userWithRoles.companyNames[r.companyId]})';
                                              }
                                              if (r.garageId != null && userWithRoles.garageNames.containsKey(r.garageId)) {
                                                roleDesc += ' [${userWithRoles.garageNames[r.garageId]}]';
                                              }
                                              return roleDesc;
                                            }).join(', '),
                                      Icons.badge,
                                    ),
                                    
                                    // Моя компания
                                    if (userWithRoles.ownedCompany != null)
                                      _buildInfoRow(
                                        'Моя компания',
                                        userWithRoles.ownedCompany!,
                                        Icons.business,
                                      ),
                                    
                                    // Мой гараж
                                    if (userWithRoles.primaryGarage != null)
                                      _buildInfoRow(
                                        'Мой гараж',
                                        userWithRoles.primaryGarage!,
                                        Icons.garage,
                                      ),
                                    
                                    // Мой менеджер
                                    if (userWithRoles.managerNames.isNotEmpty)
                                      _buildInfoRow(
                                        'Мой менеджер',
                                        userWithRoles.managerNames.values.join(', '),
                                        Icons.person_outline,
                                      ),
                                    
                                    // Мой директор
                                    if (userWithRoles.directorNames.isNotEmpty)
                                      _buildInfoRow(
                                        'Мой директор',
                                        userWithRoles.directorNames.values.join(', '),
                                        Icons.person,
                                      ),
                                    
                                    // Мой агент
                                    if (userWithRoles.agentNames.isNotEmpty)
                                      _buildInfoRow(
                                        'Мой агент',
                                        userWithRoles.agentNames.values.join(', '),
                                        Icons.support_agent,
                                      ),
                                    
                                    // Мой инвестор
                                    if (userWithRoles.investorNames.isNotEmpty)
                                      _buildInfoRow(
                                        'Мой инвестор',
                                        userWithRoles.investorNames.values.join(', '),
                                        Icons.account_balance,
                                      ),
                                    
                                    // Компания-партнер
                                    if (userWithRoles.partnerNames.isNotEmpty)
                                      _buildInfoRow(
                                        'Компания-партнер',
                                        userWithRoles.partnerNames.values.join(', '),
                                        Icons.handshake,
                                      ),
                                    
                                    // Дата создания
                                    _buildInfoRow(
                                      'Создан',
                                      _formatDateTime(user.createdAt),
                                      Icons.calendar_today,
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    // Кнопка удаления
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        label: const Text(
                                          'Удалить',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed: () => _deleteUser(user.uid, user.displayName),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
