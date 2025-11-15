import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/models.dart';
import 'user_service.dart';
import 'interface_service.dart';

enum AuthResult {
  success,
  userNotFound,
  wrongPassword,
  invalidEmail,
  emailAlreadyInUse,
  weakPassword,
  operationNotAllowed,
  networkError,
  unknown,
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final UserService _userService = UserService();

  /// Текущий пользователь Firebase Auth
  firebase_auth.User? get currentFirebaseUser => _auth.currentUser;

  /// Поток изменений состояния аутентификации
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  /// Поток изменений пользователя с данными из Firestore
  Stream<AppUser?> get userChanges => _auth.authStateChanges().asyncMap((firebaseUser) async {
    if (firebaseUser == null) return null;
    return await _userService.getById(firebaseUser.uid);
  });

  /// Регистрация нового пользователя
  Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    GlobalRole globalRole = GlobalRole.manager,
  }) async {
    try {
      // Создаем пользователя в Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) return AuthResult.unknown;

      // Создаем профиль пользователя в Firestore
      final appUser = AppUser(
        uid: firebaseUser.uid,
        email: email,
        displayName: '$firstName $lastName',
        organizations: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _userService.createWithId(firebaseUser.uid, appUser);

      // Обновляем displayName в Firebase Auth
      await firebaseUser.updateDisplayName('$firstName $lastName');

      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e);
    } catch (e) {
      return AuthResult.unknown;
    }
  }

  /// Вход с email и паролем
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e);
    } catch (e) {
      return AuthResult.unknown;
    }
  }

  /// Анонимный вход (для тестирования)
  Future<AuthResult> signInAnonymously({GlobalRole role = GlobalRole.director}) async {
    try {
      final credential = await _auth.signInAnonymously();
      final firebaseUser = credential.user;
      
      if (firebaseUser != null) {
        // Создаем профиль с указанной ролью для тестирования
        final existing = await _userService.getById(firebaseUser.uid);
        if (existing == null) {
          final roleNames = {
            GlobalRole.director: 'D (Director)',
            GlobalRole.manager: 'M (Manager)',
            GlobalRole.investor: 'I (Investor)',
            GlobalRole.guest: 'G (Guest)',
          };
          
          final appUser = AppUser(
            uid: firebaseUser.uid,
            email: role.value.substring(0, 1).toLowerCase(),
            displayName: roleNames[role] ?? 'Test User',
            organizations: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _userService.createWithId(firebaseUser.uid, appUser);
        }
      }
      
      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e);
    } catch (e) {
      return AuthResult.unknown;
    }
  }

  /// Вход через Google (поддерживает Web и мобильные платформы)
  Future<AuthResult> signInWithGoogle() async {
    print('🔵 [AUTH_SERVICE] Начало входа через Google');
    print('🔵 [AUTH_SERVICE] Платформа: ${kIsWeb ? "Web" : "Mobile"}');
    
    try {
      if (kIsWeb) {
        print('🔵 [AUTH_SERVICE] Web: создание GoogleAuthProvider');
        // Web: используем popup
        final provider = firebase_auth.GoogleAuthProvider();
        print('🔵 [AUTH_SERVICE] Web: вызов signInWithPopup');
        final userCredential = await _auth.signInWithPopup(provider);
        print('✅ [AUTH_SERVICE] Web: signInWithPopup успешен');
        print('✅ [AUTH_SERVICE] User ID: ${userCredential.user?.uid}');
        print('✅ [AUTH_SERVICE] User Email: ${userCredential.user?.email}');
        print('✅ [AUTH_SERVICE] User DisplayName: ${userCredential.user?.displayName}');
        
        // Если новый пользователь, создаем профиль в Firestore
        final firebaseUser = userCredential.user;
        if (firebaseUser != null) {
          final existing = await _userService.getById(firebaseUser.uid);
          if (existing == null) {
            print('🔵 [AUTH_SERVICE] Профиль не найден, создаем новый');
            final appUser = AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              displayName: firebaseUser.displayName ?? '',
              organizations: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _userService.createWithId(firebaseUser.uid, appUser);
            print('✅ [AUTH_SERVICE] Профиль успешно создан в Firestore');
          } else {
            print('✅ [AUTH_SERVICE] Профиль уже существует в Firestore');
          }
        }
      } else {
        print('🔵 [AUTH_SERVICE] Mobile: запуск GoogleSignIn');
        // Mobile: используем google_sign_in
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          print('⚠️ [AUTH_SERVICE] Google Sign In отменен пользователем');
          return AuthResult.unknown; // canceled
        }
        print('✅ [AUTH_SERVICE] GoogleSignIn успешен: ${googleUser.email}');
        
        print('🔵 [AUTH_SERVICE] Получение authentication токенов');
        final googleAuth = await googleUser.authentication;
        print('✅ [AUTH_SERVICE] Токены получены (idToken: ${googleAuth.idToken != null}, accessToken: ${googleAuth.accessToken != null})');
        
        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        print('🔵 [AUTH_SERVICE] Вход с credential');

        final userCred = await _auth.signInWithCredential(credential);
        print('✅ [AUTH_SERVICE] signInWithCredential успешен');
        print('✅ [AUTH_SERVICE] User ID: ${userCred.user?.uid}');
        print('✅ [AUTH_SERVICE] User Email: ${userCred.user?.email}');

        // Если новый пользователь, создаем профиль в Firestore
        final firebaseUser = userCred.user;
        if (firebaseUser != null) {
          print('🔵 [AUTH_SERVICE] Проверка существующего профиля в Firestore');
          final existing = await _userService.getById(firebaseUser.uid);
          if (existing == null) {
            print('🔵 [AUTH_SERVICE] Профиль не найден, создаем новый');
            final appUser = AppUser(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              displayName: firebaseUser.displayName ?? '',
              organizations: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _userService.createWithId(firebaseUser.uid, appUser);
            print('✅ [AUTH_SERVICE] Профиль успешно создан в Firestore');
          } else {
            print('✅ [AUTH_SERVICE] Профиль уже существует в Firestore');
          }
        }
      }

      print('✅ [AUTH_SERVICE] Вход через Google полностью завершен');
      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('❌ [AUTH_SERVICE] FirebaseAuthException: ${e.code}');
      print('❌ [AUTH_SERVICE] Message: ${e.message}');
      print('❌ [AUTH_SERVICE] Stack trace: ${e.stackTrace}');
      return _handleFirebaseAuthException(e);
    } catch (e, stackTrace) {
      print('❌ [AUTH_SERVICE] Неожиданная ошибка: $e');
      print('❌ [AUTH_SERVICE] Stack trace: $stackTrace');
      return AuthResult.unknown;
    }
  }

  /// Начать верификацию по номеру телефона (отправляет SMS)
  /// callback codeSent получит verificationId для ввода кода пользователем
  Future<AuthResult> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    void Function()? codeAutoRetrievalTimeout,
  }) async {
    print('📱 [AUTH_SERVICE] Начало верификации телефона: $phoneNumber');
    
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          print('✅ [AUTH_SERVICE] Автоматическая верификация завершена');
          print('🔵 [AUTH_SERVICE] Вход с credential...');
          // Автоматическая верификация (например, на Android)
          await _auth.signInWithCredential(credential);
          print('✅ [AUTH_SERVICE] Вход успешен через автоматическую верификацию');
        },
        verificationFailed: (e) {
          print('❌ [AUTH_SERVICE] Верификация не удалась: ${e.code}');
          print('❌ [AUTH_SERVICE] Message: ${e.message}');
          print('❌ [AUTH_SERVICE] Stack trace: ${e.stackTrace}');
          // Для простоты обработаем как неизвестную ошибку
        },
        codeSent: (verificationId, resendToken) {
          print('✅ [AUTH_SERVICE] Код отправлен');
          print('🔵 [AUTH_SERVICE] Verification ID: $verificationId');
          print('🔵 [AUTH_SERVICE] Resend Token: ${resendToken != null ? "доступен" : "null"}');
          codeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          print('⏱️ [AUTH_SERVICE] Таймаут автоматического получения кода');
          print('🔵 [AUTH_SERVICE] Verification ID: $verificationId');
          if (codeAutoRetrievalTimeout != null) codeAutoRetrievalTimeout();
        },
      );

      print('✅ [AUTH_SERVICE] verifyPhoneNumber вызов завершен');
      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('❌ [AUTH_SERVICE] FirebaseAuthException: ${e.code}');
      print('❌ [AUTH_SERVICE] Message: ${e.message}');
      return _handleFirebaseAuthException(e);
    } catch (e, stackTrace) {
      print('❌ [AUTH_SERVICE] Неожиданная ошибка: $e');
      print('❌ [AUTH_SERVICE] Stack trace: $stackTrace');
      return AuthResult.unknown;
    }
  }

  /// Вход по sms коду после получения verificationId
  Future<AuthResult> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    print('📱 [AUTH_SERVICE] Вход с SMS кодом');
    print('🔵 [AUTH_SERVICE] Verification ID: $verificationId');
    print('🔵 [AUTH_SERVICE] SMS Code: $smsCode');
    
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      print('🔵 [AUTH_SERVICE] Credential создан, вход...');

      final userCredential = await _auth.signInWithCredential(credential);
      print('✅ [AUTH_SERVICE] Вход успешен');
      print('✅ [AUTH_SERVICE] User ID: ${userCredential.user?.uid}');
      print('✅ [AUTH_SERVICE] Phone: ${userCredential.user?.phoneNumber}');
      
      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('❌ [AUTH_SERVICE] FirebaseAuthException: ${e.code}');
      print('❌ [AUTH_SERVICE] Message: ${e.message}');
      return _handleFirebaseAuthException(e);
    } catch (e, stackTrace) {
      print('❌ [AUTH_SERVICE] Неожиданная ошибка: $e');
      print('❌ [AUTH_SERVICE] Stack trace: $stackTrace');
      return AuthResult.unknown;
    }
  }

  /// Выход из аккаунта
  Future<void> signOut() async {
    // Очищаем сохраненный тип интерфейса
    await InterfaceService().clearInterfaceType();
    await _auth.signOut();
  }

  /// Сброс пароля
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e);
    } catch (e) {
      return AuthResult.unknown;
    }
  }

  /// Изменение пароля
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.userNotFound;

      // Переаутентификация пользователя
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e);
    } catch (e) {
      return AuthResult.unknown;
    }
  }

  /// Получить текущего пользователя из Firestore
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = currentFirebaseUser;
    if (firebaseUser == null) return null;

    return await _userService.getById(firebaseUser.uid);
  }

  /// Обновить профиль пользователя
  Future<void> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    final firebaseUser = currentFirebaseUser;
    if (firebaseUser == null) return;

    // Обновляем в Firestore
    final updates = <String, dynamic>{};
    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (email != null) updates['email'] = email;

    if (updates.isNotEmpty) {
      updates['updated_at'] = Timestamp.now();
      await _userService.updateFields(firebaseUser.uid, updates);
    }

    // Обновляем в Firebase Auth
    if (firstName != null || lastName != null) {
      final currentUser = await getCurrentUser();
      final currentDisplayName = currentUser?.displayName ?? '';
      final names = currentDisplayName.split(' ');
      final currentFirstName = names.isNotEmpty ? names.first : '';
      final currentLastName = names.length > 1 ? names.last : '';
      
      final displayName = '${firstName ?? currentFirstName} ${lastName ?? currentLastName}';
      await firebaseUser.updateDisplayName(displayName);
      
      // Обновляем также в Firestore
      updates['display_name'] = displayName;
    }

    if (email != null && email != firebaseUser.email) {
      await firebaseUser.verifyBeforeUpdateEmail(email);
    }
  }

  /// Проверить права доступа пользователя
  Future<bool> hasAccess({
    required GlobalRole requiredGlobalRole,
    String? organizationId,
  }) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    // TODO: Переделать для контекстных ролей
    // Временно возвращаем false
    return false;
    
    // // Проверяем глобальную роль
    // if (user.globalRole.index <= requiredGlobalRole.index) {
    //   // Если указана организация, проверяем доступ к ней
    //   if (organizationId != null) {
    //     return user.hasAccessToOrganization(organizationId);
    //   }
    //   return true;
    // }
    //
    // return false;
  }

  // ============ ПРОВЕРКА ПРАВ НА ОСНОВЕ ГЛОБАЛЬНЫХ РОЛЕЙ ============

  /// Может ли пользователь приглашать/добавлять MANAGER в компанию
  Future<bool> canInviteManager() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // TODO: Переделать для контекстных ролей
    return false;
    // // DIRECTOR - Да, MANAGER - Да, INVESTOR - Нет, GUEST - Нет
    // return user.globalRole == GlobalRole.director || user.globalRole == GlobalRole.manager;
  }

  /// Может ли пользователь приглашать/добавлять INVESTOR в компанию  
  Future<bool> canInviteInvestor() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // TODO: Переделать для контекстных ролей
    return false;
    // // DIRECTOR - Да, MANAGER - Нет, INVESTOR - Нет, GUEST - Нет
    // return user.globalRole == GlobalRole.director;
  }

  /// Может ли пользователь просматривать отчетность/финансы
  Future<bool> canViewReports({String? organizationId}) async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // TODO: Переделать для контекстных ролей
    return false;
    
    // switch (user.globalRole) {
    //   case GlobalRole.director:
    //   case GlobalRole.manager:
    //   case GlobalRole.investor:
    //     // Доступ только к своим организациям
    //     if (organizationId != null) {
    //       return user.hasAccessToOrganization(organizationId);
    //     }
    //     return false;
    //   case GlobalRole.guest:
    //     // GUEST не имеет доступа к финансам
    //     return false;
    // }
  }

  /// Может ли пользователь управлять автомобилями
  Future<bool> canManageCars({String? organizationId}) async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // TODO: Переделать для контекстных ролей
    return false;
    
    // switch (user.globalRole) {
    //   case GlobalRole.director:
    //   case GlobalRole.manager:
    //   case GlobalRole.investor:
    //     // Доступ к автомобилям своей организации
    //     if (organizationId != null) {
    //       return user.hasAccessToOrganization(organizationId);
    //     }
    //     return false;
    //   case GlobalRole.guest:
    //     return false; // GUEST не может управлять авто
    // }
  }

  /// Может ли пользователь управлять бронированием
  Future<bool> canManageBookings({String? organizationId}) async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // TODO: Переделать для контекстных ролей
    return false;
    
    // switch (user.globalRole) {
    //   case GlobalRole.director:
    //     return true; // Полный доступ к бронированию
    //   case GlobalRole.manager:
    //     // Может работать с бронями в своих организациях
    //     if (organizationId != null) {
    //       return user.hasAccessToOrganization(organizationId);
    //     }
    //     return false;
    //   case GlobalRole.investor:
    //     return false; // Инвесторы не работают с бронированием
    //   case GlobalRole.guest:
    //     return false; // GUEST не работает с бронированием
    // }
  }

  // ============ НОВАЯ СИСТЕМА РАЗРЕШЕНИЙ ============

  /// Проверить, есть ли у пользователя определенное разрешение
  Future<bool> hasPermission(Permission permission) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    // TODO: Переделать для контекстных ролей
    return false;
    // return PermissionMatrix.hasPermission(user.globalRole, permission);
  }

  /// Получить все разрешения пользователя
  Future<Set<Permission>> getUserPermissions() async {
    final user = await getCurrentUser();
    if (user == null) return <Permission>{};

    // TODO: Переделать для контекстных ролей
    return <Permission>{};
    // return PermissionMatrix.getUserPermissions(user.globalRole);
  }

  /// Получить организации пользователя
  Future<List<String>> getUserOrganizations() async {
    final user = await getCurrentUser();
    return user?.organizations ?? [];
  }

  /// Удалить аккаунт пользователя
  Future<AuthResult> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return AuthResult.userNotFound;

      // Переаутентификация
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Удаляем из Firestore
      await _userService.delete(user.uid);

      // Удаляем из Firebase Auth
      await user.delete();

      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e);
    } catch (e) {
      return AuthResult.unknown;
    }
  }

  /// Отправить письмо для подтверждения email
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = currentFirebaseUser;
      if (user == null) return AuthResult.userNotFound;

      await user.sendEmailVerification();
      return AuthResult.success;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e);
    } catch (e) {
      return AuthResult.unknown;
    }
  }

  /// Проверить, подтвержден ли email
  bool get isEmailVerified => currentFirebaseUser?.emailVerified ?? false;

  /// Обновить информацию о пользователе
  Future<void> reloadUser() async {
    await currentFirebaseUser?.reload();
  }

  /// Обработка исключений Firebase Auth
  AuthResult _handleFirebaseAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthResult.userNotFound;
      case 'wrong-password':
        return AuthResult.wrongPassword;
      case 'invalid-email':
        return AuthResult.invalidEmail;
      case 'email-already-in-use':
        return AuthResult.emailAlreadyInUse;
      case 'weak-password':
        return AuthResult.weakPassword;
      case 'operation-not-allowed':
        return AuthResult.operationNotAllowed;
      case 'network-request-failed':
        return AuthResult.networkError;
      default:
        return AuthResult.unknown;
    }
  }

  /// Получить текстовое описание результата аутентификации
  String getAuthResultMessage(AuthResult result) {
    switch (result) {
      case AuthResult.success:
        return 'Операция выполнена успешно';
      case AuthResult.userNotFound:
        return 'Пользователь не найден';
      case AuthResult.wrongPassword:
        return 'Неверный пароль';
      case AuthResult.invalidEmail:
        return 'Неверный формат email';
      case AuthResult.emailAlreadyInUse:
        return 'Email уже используется';
      case AuthResult.weakPassword:
        return 'Слишком слабый пароль';
      case AuthResult.operationNotAllowed:
        return 'Операция не разрешена';
      case AuthResult.networkError:
        return 'Ошибка сети';
      case AuthResult.unknown:
        return 'Неизвестная ошибка';
    }
  }
}