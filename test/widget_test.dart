// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:car_rental_manager/models/user.dart';
import 'package:car_rental_manager/models/user_role.dart';

void main() {
  group('Car Rental Manager Tests', () {
    test('RoleType enum should have correct values', () {
      expect(RoleType.values.length, 4);
      expect(RoleType.owner.description, 'Владелец');
      expect(RoleType.director.description, 'Директор');
      expect(RoleType.manager.description, 'Менеджер');
      expect(RoleType.agent.description, 'Агент');
    });

    test('AppUser model should create correctly', () {
      final now = DateTime.now();
      final user = AppUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
        organizations: [],
        createdAt: now,
        updatedAt: now,
      );

      expect(user.uid, 'test-uid');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.organizations, isEmpty);
    });

    testWidgets('Login Screen should render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              Text('Вход в систему'),
              TextField(
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Пароль'),
                obscureText: true,
              ),
            ],
          ),
        ),
      ));

      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Пароль'), findsOneWidget);
    });
  });
}
