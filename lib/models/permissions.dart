import 'user.dart';

/// Перечисление всех разрешений в системе согласно таблице прав доступа
enum Permission {
  // Системные права
  systemAccess('SYSTEM_ACCESS'),
  
  // Управление пользователями
  inviteManager('INVITE_MANAGER'),
  inviteInvestor('INVITE_OWNER'),
  
  // Отчетность и финансы
  viewAllReports('VIEW_ALL_REPORTS'),
  viewCompanyReports('VIEW_COMPANY_REPORTS'), 
  viewOwnReports('VIEW_OWN_REPORTS'),
  
  // Управление автомобилями
  addEditTransferCars('ADD_EDIT_TRANSFER_CARS'),
  deleteCars('DELETE_CARS'),
  viewCarCalendar('VIEW_CAR_CALENDAR'),
  
  // Бронирование и аренда
  createBookingRequest('CREATE_BOOKING_REQUEST'),
  manageBookings('MANAGE_BOOKINGS'),
  confirmBookings('CONFIRM_BOOKINGS'),
  grantManagerBookingRights('GRANT_MANAGER_BOOKING_RIGHTS'),
  grantBookingWithoutConfirmation('GRANT_BOOKING_WITHOUT_CONFIRMATION'),
  grantBookingConfirmationRights('GRANT_BOOKING_CONFIRMATION_RIGHTS');

  const Permission(this.value);
  final String value;

  static Permission fromString(String value) {
    return Permission.values.firstWhere(
      (permission) => permission.value == value,
      orElse: () => Permission.systemAccess,
    );
  }

  /// Получить описание разрешения
  String get description {
    switch (this) {
      case Permission.systemAccess:
        return 'Вход и доступ к системе';
      case Permission.inviteManager:
        return 'Приглашать/добавлять MANAGER в компанию';
      case Permission.inviteInvestor:
        return 'Приглашать/добавлять OWNER в компанию';
      case Permission.viewAllReports:
        return 'Отчетность/Финансы (все)';
      case Permission.viewCompanyReports:
        return 'Отчетность/Финансы (только авто компании)';
      case Permission.viewOwnReports:
        return 'Отчетность/Финансы (только свои)';
      case Permission.addEditTransferCars:
        return 'Добавлять/Редактировать/передавать Авто';
      case Permission.deleteCars:
        return 'Удалять авто';
      case Permission.viewCarCalendar:
        return 'Просмотр наличия свободных авто (календарь)';
      case Permission.createBookingRequest:
        return 'Подавать заявку (требует подтверждения для перевода в статус брони)';
      case Permission.manageBookings:
        return 'Бронирование';
      case Permission.confirmBookings:
        return 'Подтверждать заявки (переводить их в статус брони)';
      case Permission.grantManagerBookingRights:
        return 'Выдать право менеджеру на подачу заявки';
      case Permission.grantBookingWithoutConfirmation:
        return 'Выдать право менеджеру на Бронирование без необходимости подтверждения';
      case Permission.grantBookingConfirmationRights:
        return 'Выдать право подтверждать заявки (переводить их в статус брони)';
    }
  }
}

/// Класс для проверки разрешений на основе ролей согласно таблице
class PermissionMatrix {
  /// Получить все разрешения для глобальной роли
  static Set<Permission> getGlobalPermissions(GlobalRole role) {
    switch (role) {
      case GlobalRole.director:
        return {
          Permission.systemAccess,
          Permission.inviteManager,
          Permission.inviteInvestor,
          Permission.viewCompanyReports,
          Permission.addEditTransferCars,
          Permission.deleteCars,
          Permission.viewCarCalendar,
          Permission.manageBookings,
          Permission.confirmBookings,
          Permission.grantManagerBookingRights,
          Permission.grantBookingWithoutConfirmation,
          Permission.grantBookingConfirmationRights,
        };
        
      case GlobalRole.manager:
        return {
          Permission.systemAccess,
          Permission.inviteManager,
          Permission.viewOwnReports,
          // Остальные права по разрешению DIRECTOR
        };
        
      case GlobalRole.investor:
        return {
          Permission.systemAccess,
          Permission.viewOwnReports,
          Permission.addEditTransferCars, // Только свои авто
          Permission.deleteCars,          // Только свои авто
        };
        
      case GlobalRole.guest:
        return {
          Permission.systemAccess,
          Permission.viewCarCalendar, // Только просмотр календаря
          // Без прав на создание/изменение
        };
    }
  }

  /// Проверить, есть ли у роли определенное разрешение
  static bool hasPermission(GlobalRole role, Permission permission) {
    final globalPermissions = getGlobalPermissions(role);
    return globalPermissions.contains(permission);
  }

  /// Получить все разрешения пользователя
  static Set<Permission> getUserPermissions(GlobalRole globalRole) {
    return getGlobalPermissions(globalRole);
  }
}

