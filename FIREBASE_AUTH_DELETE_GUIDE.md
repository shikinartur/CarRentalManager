# Руководство по удалению пользователей Firebase Auth

## Проблема

Firebase Auth не позволяет удалять пользователей программно из клиентского приложения по соображениям безопасности. Пользователь может удалить только сам себя, находясь в залогиненном состоянии.

## Текущее решение (временное)

Приложение использует следующий подход:
1. **Автоматическая генерация уникальных email** - кнопка ✨ рядом с полем Email
2. **Кнопка "Быстрое создание"** - автоматически создает пользователя с уникальным email
3. **Предупреждения** - пользователь предупреждается, что email останутся занятыми

## Правильное решение (Cloud Functions)

Для полного удаления пользователей из Firebase Auth необходимо использовать **Firebase Cloud Functions** с **Admin SDK**.

### Шаг 1: Установка Firebase CLI

```bash
npm install -g firebase-tools
firebase login
firebase init functions
```

### Шаг 2: Создание Cloud Function

Создайте файл `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Cloud Function для удаления тестового пользователя
exports.deleteTestUser = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Требуется аутентификация'
    );
  }

  const userId = data.userId;
  
  // Проверка, что пользователь тестовый
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(userId)
    .get();
    
  if (!userDoc.exists || !userDoc.data().isTestUser) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Можно удалять только тестовых пользователей'
    );
  }

  try {
    // Удаление из Firebase Auth
    await admin.auth().deleteUser(userId);
    
    // Удаление ролей
    const rolesSnapshot = await admin.firestore()
      .collection('user_roles')
      .where('userId', '==', userId)
      .get();
      
    const batch = admin.firestore().batch();
    rolesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Удаление документа пользователя
    batch.delete(admin.firestore().collection('users').doc(userId));
    
    await batch.commit();
    
    return { success: true, message: 'Пользователь удален' };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Ошибка удаления пользователя: ' + error.message
    );
  }
});

// Cloud Function для удаления всех тестовых пользователей
exports.deleteAllTestUsers = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Требуется аутентификация'
    );
  }

  try {
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('isTestUser', '==', true)
      .get();
    
    const deletePromises = usersSnapshot.docs.map(async (doc) => {
      const userId = doc.id;
      
      // Удаление из Auth
      try {
        await admin.auth().deleteUser(userId);
      } catch (error) {
        console.error(`Ошибка удаления пользователя ${userId} из Auth:`, error);
      }
      
      // Удаление ролей
      const rolesSnapshot = await admin.firestore()
        .collection('user_roles')
        .where('userId', '==', userId)
        .get();
        
      const batch = admin.firestore().batch();
      rolesSnapshot.docs.forEach(roleDoc => {
        batch.delete(roleDoc.ref);
      });
      
      // Удаление документа
      batch.delete(doc.ref);
      
      await batch.commit();
    });
    
    await Promise.all(deletePromises);
    
    return { 
      success: true, 
      message: `Удалено ${usersSnapshot.size} пользователей` 
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Ошибка удаления пользователей: ' + error.message
    );
  }
});
```

### Шаг 3: Развертывание функций

```bash
firebase deploy --only functions
```

### Шаг 4: Использование в Flutter

Добавьте зависимость в `pubspec.yaml`:

```yaml
dependencies:
  cloud_functions: ^5.1.3
```

Обновите сервис `test_user_service.dart`:

```dart
import 'package:cloud_functions/cloud_functions.dart';

class TestUserService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  Future<void> deleteTestUser(String userId) async {
    try {
      final callable = _functions.httpsCallable('deleteTestUser');
      await callable.call({'userId': userId});
    } catch (e) {
      throw Exception('Ошибка удаления пользователя: $e');
    }
  }
  
  Future<void> deleteAllTestUsers() async {
    try {
      final callable = _functions.httpsCallable('deleteAllTestUsers');
      await callable.call();
    } catch (e) {
      throw Exception('Ошибка удаления пользователей: $e');
    }
  }
}
```

### Шаг 5: Настройка безопасности

В Firebase Console установите правила для функций:
- Функции должны вызываться только аутентифицированными пользователями
- Можно добавить проверку роли администратора

## Альтернативные решования

### 1. Firebase Authentication REST API с Admin SDK
Использовать Firebase Admin SDK на сервере

### 2. Эмулятор Firebase
Для разработки можно использовать Firebase Emulator Suite, который позволяет полностью очищать данные

```bash
firebase emulators:start
```

### 3. Использование тестовых префиксов
Создавать пользователей с уникальными префиксами: `test_timestamp@test.com`

## Рекомендации

1. **В продакшене**: Используйте Cloud Functions
2. **В разработке**: Используйте уникальные email с timestamp
3. **Для автоматических тестов**: Используйте Firebase Emulator Suite
4. **Документируйте**: Храните список тестовых пользователей отдельно

## Стоимость

Firebase Cloud Functions:
- Бесплатный план: 2M вызовов/месяц
- Платный план: $0.40 за 1M вызовов

Для тестирования обычно достаточно бесплатного плана.
