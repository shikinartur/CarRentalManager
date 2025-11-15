import 'package:flutter/material.dart';
import '../../services/services.dart';
import '../screens/auth/simple_login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Загрузка...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Пользователь авторизован - показываем главный экран (Dashboard)
          return const DashboardScreen();
        } else {
          // Пользователь не авторизован - показываем экран входа
          return const LoginScreen();
        }
      },
    );
  }
}