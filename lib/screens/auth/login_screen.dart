import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/interface_service.dart';
import '../../utils/create_test_users.dart';
import '../../utils/test_data_generator.dart';
import 'register_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  final InterfaceType interfaceType;
  
  const LoginScreen({
    super.key,
    required this.interfaceType,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _testDataGenerator = TestDataGenerator();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _isCreatingTestData = false;

  /// Получить конфигурацию интерфейса в зависимости от типа
  Map<String, dynamic> _getInterfaceConfig() {
    switch (widget.interfaceType) {
      case InterfaceType.investor:
        return {
          'icon': Icons.account_balance,
          'title': 'Вход для инвестора',
          'color': Colors.green,
        };
      case InterfaceType.rental:
        return {
          'icon': Icons.car_rental,
          'title': 'Вход для прокатчика',
          'color': Colors.blue,
        };
      case InterfaceType.agent:
        return {
          'icon': Icons.support_agent,
          'title': 'Вход для агента',
          'color': Colors.orange,
        };
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (result == AuthResult.success) {
          // Сохраняем выбранный тип интерфейса
          await InterfaceService().saveInterfaceType(widget.interfaceType);
          // AuthWrapper автоматически покажет MainScreen после успешного входа
        } else {
          setState(() {
            _errorMessage = _authService.getAuthResultMessage(result);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Произошла ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Введите email для восстановления пароля';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.resetPassword(email);
      
      if (mounted) {
        if (result == AuthResult.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Инструкции для восстановления пароля отправлены на email'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _errorMessage = _authService.getAuthResultMessage(result);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Произошла ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Быстрый вход тестового пользователя
  Future<void> _quickLogin(String role) async {
    final userData = TestDataGenerator.testUsers[role];
    if (userData == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.signInWithEmailAndPassword(
        email: userData['email']!,
        password: userData['password']!,
      );

      if (mounted) {
        if (result == AuthResult.success) {
          // Сохраняем выбранный тип интерфейса
          await InterfaceService().saveInterfaceType(widget.interfaceType);
        } else {
          setState(() {
            _errorMessage = _authService.getAuthResultMessage(result);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Создать тестовые данные
  Future<void> _createTestData() async {
    setState(() {
      _isCreatingTestData = true;
      _errorMessage = null;
    });

    try {
      await _testDataGenerator.createTestData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Тестовые данные созданы!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка создания данных: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTestData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определяем цвет и заголовок в зависимости от типа интерфейса
    final interfaceConfig = _getInterfaceConfig();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Логотип и заголовок
                        Icon(
                          interfaceConfig['icon'] as IconData,
                          size: 64,
                          color: interfaceConfig['color'] as Color,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          interfaceConfig['title'] as String,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: interfaceConfig['color'] as Color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Вход в систему',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Поле Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Введите ваш email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Введите email';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'Введите корректный email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Поле Пароль
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            hintText: 'Введите ваш пароль',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible 
                                  ? Icons.visibility_off 
                                  : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите пароль';
                            }
                            if (value.length < 6) {
                              return 'Пароль должен содержать минимум 6 символов';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Ссылка "Забыли пароль?"
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            child: const Text('Забыли пароль?'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Сообщение об ошибке
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              border: Border.all(color: Colors.red[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, 
                                     color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Кнопка входа
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Войти',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),

                        // Разделитель
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'или',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Быстрый вход (тестовые пользователи)
                        if (widget.interfaceType == InterfaceType.rental) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : () => _quickLogin('director'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Директор\n(тест)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : () => _quickLogin('manager'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[500],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Менеджер\n(тест)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.interfaceType == InterfaceType.investor) ...[
                          ElevatedButton(
                            onPressed: _isLoading ? null : () => _quickLogin('investor'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Инвестор (тест)', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                        if (widget.interfaceType == InterfaceType.agent) ...[
                          ElevatedButton(
                            onPressed: _isLoading ? null : () => _quickLogin('agent'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Агент (тест)', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Кнопка создания тестовых данных
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isCreatingTestData ? null : _createTestData,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[400]!),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isCreatingTestData
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.science, size: 16),
                            label: Text(
                              _isCreatingTestData ? 'Создание...' : 'Создать тестовые данные',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Социальный вход (Google)
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 20, color: Colors.red),
                          label: const Text('Войти через Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Phone Auth временно отключена (требуется Firebase Blaze план)
                        // const SizedBox(height: 12),
                        // OutlinedButton.icon(
                        //   onPressed: _isLoading ? null : _signInWithPhone,
                        //   icon: const Icon(Icons.phone_outlined),
                        //   label: const Text('Войти по телефону'),
                        //   style: OutlinedButton.styleFrom(
                        //     padding: const EdgeInsets.symmetric(vertical: 14),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(12),
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 24),

                        // Кнопка регистрации
                        OutlinedButton(
                          onPressed: _isLoading 
                              ? null 
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Theme.of(context).primaryColor),
                          ),
                          child: Text(
                            'Создать аккаунт',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Кнопка для создания тестовых пользователей (только для разработки)
                        TextButton.icon(
                          onPressed: _isLoading 
                              ? null 
                              : () async {
                                  setState(() => _isLoading = true);
                                  try {
                                    await createTestUsers();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✓ Тестовые пользователи созданы!\n'
                                              'm@m.m (MANAGER)\n'
                                              'd@d.d (DIRECTOR)\n'
                                              'o@o.o (OWNER)\n'
                                              'Пароль для всех: 111111'),
                                          duration: Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Ошибка: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.people_outline, size: 16),
                          label: const Text(
                            'Создать тестовых пользователей',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    print('🔵 [LOGIN_SCREEN] Начало входа через Google');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔵 [LOGIN_SCREEN] Вызов authService.signInWithGoogle()');
      final result = await _authService.signInWithGoogle();
      print('🔵 [LOGIN_SCREEN] Результат: $result');
      
      if (!mounted) return;
      if (result == AuthResult.success) {
        print('✅ [LOGIN_SCREEN] Успешный вход. AuthWrapper покажет MainScreen');
        // AuthWrapper автоматически переключит на MainScreen
      } else {
        print('❌ [LOGIN_SCREEN] Ошибка входа: $result');
        setState(() {
          _errorMessage = _authService.getAuthResultMessage(result);
        });
      }
    } catch (e, stackTrace) {
      print('❌ [LOGIN_SCREEN] Исключение: $e');
      print('❌ [LOGIN_SCREEN] Stack trace: $stackTrace');
      if (mounted) setState(() => _errorMessage = 'Ошибка: $e');
    } finally {
      if (mounted) {
        print('🔵 [LOGIN_SCREEN] Завершение входа через Google');
        setState(() => _isLoading = false);
      }
    }
  }

  // Phone Auth временно отключена - требуется Firebase Blaze план для активации
  // Future<void> _signInWithPhone() async {
  //   print('📱 [LOGIN_SCREEN] Начало входа по телефону');
  //   final phoneController = TextEditingController();
  //
  //   // Шаг 1: ввод номера телефона
  //   final phone = await showDialog<String?>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Вход по телефону'),
  //       content: TextField(
  //         controller: phoneController,
  //         keyboardType: TextInputType.phone,
  //         decoration: const InputDecoration(labelText: 'Номер телефона (+7...)'),
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Отмена')),
  //         ElevatedButton(onPressed: () => Navigator.of(context).pop(phoneController.text.trim()), child: const Text('Отправить')),
  //       ],
  //     ),
  //   );
  //
  //   if (phone == null || phone.isEmpty) {
  //     print('⚠️ [LOGIN_SCREEN] Ввод телефона отменен');
  //     return;
  //   }
  //   
  //   print('🔵 [LOGIN_SCREEN] Введен номер: $phone');
  //
  //   setState(() { _isLoading = true; _errorMessage = null; });
  //
  //   try {
  //     print('🔵 [LOGIN_SCREEN] Вызов verifyPhoneNumber');
  //     final res = await _authService.verifyPhoneNumber(
  //       phoneNumber: phone,
  //       codeSent: (verificationId) async {
  //         print('✅ [LOGIN_SCREEN] Получен verificationId: $verificationId');
  //         // Шаг 2: ввод кода
  //         final codeController = TextEditingController();
  //         final sms = await showDialog<String?>(
  //           context: context,
  //           builder: (context) => AlertDialog(
  //             title: const Text('Введите код из SMS'),
  //             content: TextField(
  //               controller: codeController,
  //               keyboardType: TextInputType.number,
  //               decoration: const InputDecoration(labelText: 'Код'),
  //             ),
  //             actions: [
  //               TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Отмена')),
  //               ElevatedButton(onPressed: () => Navigator.of(context).pop(codeController.text.trim()), child: const Text('Войти')),
  //             ],
  //           ),
  //         );
  //
  //         if (sms == null || sms.isEmpty) {
  //           print('⚠️ [LOGIN_SCREEN] Ввод кода отменен');
  //           return;
  //         }
  //         
  //         print('🔵 [LOGIN_SCREEN] Введен код: $sms');
  //         print('🔵 [LOGIN_SCREEN] Вызов signInWithSmsCode');
  //
  //         final signInRes = await _authService.signInWithSmsCode(
  //           verificationId: verificationId,
  //           smsCode: sms,
  //         );
  //
  //         print('🔵 [LOGIN_SCREEN] Результат signInWithSmsCode: $signInRes');
  //
  //         if (!mounted) return;
  //         if (signInRes == AuthResult.success) {
  //           print('✅ [LOGIN_SCREEN] Успешный вход, переход на Dashboard');
  //           Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
  //         } else {
  //           print('❌ [LOGIN_SCREEN] Ошибка входа: $signInRes');
  //           setState(() { _errorMessage = _authService.getAuthResultMessage(signInRes); });
  //         }
  //       },
  //     );
  //
  //     print('🔵 [LOGIN_SCREEN] Результат verifyPhoneNumber: $res');
  //     if (res != AuthResult.success) {
  //       setState(() { _errorMessage = _authService.getAuthResultMessage(res); });
  //     }
  //   } catch (e, stackTrace) {
  //     print('❌ [LOGIN_SCREEN] Исключение: $e');
  //     print('❌ [LOGIN_SCREEN] Stack trace: $stackTrace');
  //     if (mounted) setState(() { _errorMessage = 'Ошибка: $e'; });
  //   } finally {
  //     if (mounted) {
  //       print('🔵 [LOGIN_SCREEN] Завершение входа по телефону');
  //       setState(() { _isLoading = false; });
  //     }
  //   }
  // }
}
