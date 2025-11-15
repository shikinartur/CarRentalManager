# Руководство по использованию структуры базы данных Car Rental Manager

## 📋 Оглавление
1. [Обзор архитектуры](#обзор-архитектуры)
2. [Модели данных](#модели-данных)
3. [Примеры использования](#примеры-использования)
4. [Управление правами доступа](#управление-правами-доступа)
5. [Миграция существующих данных](#миграция-существующих-данных)

---

## 🏗 Обзор архитектуры

### Принцип "Один актив — два субъекта ответственности"

Система реализует разделение **владения** и **управления** автомобилями:

- **Владелец (Investor)** - юридический собственник автомобиля
- **Управляющий (Manager/Director)** - кто управляет автопарком и сдает в аренду

### Типы гаражей

1. **Personal Garage** - личный гараж владельца-инвестора (INVESTOR)
   - Владелец может иметь несколько авто
   - Может передать управление компании (опционально)
   - Получает доход за вычетом комиссии управляющей компании

2. **Company Garage** - корпоративный гараж компании
   - Компания владеет автомобилями
   - DIRECTOR управляет автопарком
   - Полный контроль над операциями

---

## 📦 Модели данных

### 1. User (Пользователь)

```dart
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final GlobalRole globalRole;  // DIRECTOR, MANAGER, INVESTOR, GUEST
  final List<String> organizations;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Роли:**
- `DIRECTOR` - Управляющий автопарком
- `MANAGER` - Операционный менеджер
- `INVESTOR` - Владелец-инвестор
- `GUEST` - Гость с правами просмотра

### 2. Garage (Гараж)

```dart
// Личный гараж (любой пользователь)
class PersonalGarage extends Garage {
  final String ownerId;              // USER_id владельца (INVESTOR, DIRECTOR, MANAGER, GUEST)
  final String? managingCompanyId;   // COMPANY_id управляющей компании
  final double commissionRate;       // Процент комиссии
}

// Корпоративный гараж (только компании)
class CompanyGarage extends Garage {
  final String companyId;            // COMPANY_id владеющей компании
  final String directorId;           // USER_id директора
}
```

**Важно:**
- **Любой USER** может иметь PersonalGarage (INVESTOR, DIRECTOR, MANAGER, GUEST)
- INVESTOR - владелец-инвестор, может передать управление компании
- DIRECTOR - может иметь личные авто помимо корпоративных
- MANAGER - может владеть авто, но управлять только через компанию
- GUEST - может владеть авто, но только просматривать данные

### 3. Car (Автомобиль)

```dart
class Car {
  // Владение (ОДИН гараж на автомобиль)
  final String ownerId;        // USER_id владельца
  final String garageId;       // ID гаража (ТОЛЬКО ОДИН)
  final GarageType garageType; // PERSONAL или COMPANY
  
  // Управление
  final String? companyId;     // COMPANY_id управляющей компании
  
  // Основные данные
  final String make;
  final String model;
  final String licensePlate;
  final CarStatus status;
  final double dailyRate;
  final double monthlyRate;
  // ...
}
```

**Важное правило:**
- ⚠️ **Каждый автомобиль принадлежит ТОЛЬКО ОДНОМУ гаражу**
- Либо `personal_garage_XXX` (личный гараж пользователя)
- Либо `COMPANY_garage_XXX` (корпоративный гараж компании)
- Смена гаража = передача автомобиля другому владельцу/компании

### 4. CarPermissions (Права на автомобиль)

```dart
class CarPermissions {
  final String userId;
  final String carId;
  final bool canView;
  final bool canEdit;
  final bool canBook;
  final bool canConfirmBooking;
  final bool canViewFinancials;
  final DateTime grantedAt;
  final String grantedBy;
}
```

### 5. Rental (Аренда)

```dart
class Rental {
  final String carId;
  final String clientId;
  final String rentalUserId;         // Создатель брони
  final String carOwnerId;           // Владелец авто
  final String? managingCompanyId;   // Управляющая компания
  
  // Финансы
  final double priceAmount;          // Сумма для клиента
  final double commissionAmount;     // Комиссия
  final double depositAmount;        // Залог
  final double ownerEarnings;        // Прибыль владельца
  
  final RentalStatus status;
  // ...
}
```

---

## 💡 Примеры использования

### Создание личного гаража (для любого пользователя)

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:car_rental_manager/models/models.dart';

Future<void> createPersonalGarage({
  required String ownerId,        // Любой USER (INVESTOR, DIRECTOR, MANAGER, GUEST)
  required String name,
  String? managingCompanyId,
  double commissionRate = 0.0,
}) async {
  final garage = PersonalGarage(
    id: 'personal_garage_${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    ownerId: ownerId,
    managingCompanyId: managingCompanyId,
    commissionRate: commissionRate,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await FirebaseFirestore.instance
      .collection('garages')
      .doc(garage.id)
      .set(garage.toFirestore());
      
  print('Личный гараж создан: ${garage.id}');
}

// Пример использования для разных ролей:

// INVESTOR создает личный гараж с управляющей компанией
await createPersonalGarage(
  ownerId: investorUserId,
  name: 'Мой инвестиционный автопарк',
  managingCompanyId: 'ORG_123',
  commissionRate: 0.15,  // 15% компании
);

// DIRECTOR создает личный гараж (помимо корпоративного)
await createPersonalGarage(
  ownerId: directorUserId,
  name: 'Личные автомобили',
  managingCompanyId: null,  // Управляет сам
);

// MANAGER создает личный гараж
await createPersonalGarage(
  ownerId: managerUserId,
  name: 'Мои автомобили',
  managingCompanyId: 'ORG_456',  // Обязательно через компанию
);
```

### Создание корпоративного гаража

```dart
Future<void> createCompanyGarage({
  required String companyId,
  required String directorId,
  required String name,
}) async {
  final garage = CompanyGarage(
    id: 'COMPANY_garage_${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    companyId: companyId,
    directorId: directorId,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await FirebaseFirestore.instance
      .collection('garages')
      .doc(garage.id)
      .set(garage.toFirestore());
      
  print('Корпоративный гараж создан: ${garage.id}');
}
```

### Добавление автомобиля в личный гараж

```dart
Future<void> addCarToPersonalGarage({
  required String ownerId,
  required String garageId,
  String? managingCompanyId,
  required String make,
  required String model,
  required String licensePlate,
  required double dailyRate,
  required double monthlyRate,
}) async {
  final car = Car(
    id: FirebaseFirestore.instance.collection('cars').doc().id,
    ownerId: ownerId,
    garageId: garageId,
    garageType: GarageType.personal,
    companyId: managingCompanyId,
    make: make,
    model: model,
    licensePlate: licensePlate,
    status: CarStatus.available,
    dailyRate: dailyRate,
    monthlyRate: monthlyRate,
    photosLinks: [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await FirebaseFirestore.instance
      .collection('cars')
      .doc(car.id)
      .set(car.toFirestore());
      
  print('Автомобиль добавлен: ${car.fullName}');
}
```

### Передача автомобиля в другой гараж

```dart
import 'package:car_rental_manager/services/car_service.dart';

final carService = CarService();

// Передать автомобиль из личного гаража в корпоративный
// ОДИН гараж заменяется на другой ОДИН гараж
await carService.transferCarToGarage(
  carId: 'CAR_123',
  newOwnerId: 'COMPANY_456',              // Новый владелец
  newGarageId: 'COMPANY_garage_456',      // Новый гараж (ОДИН)
  newGarageType: 'COMPANY',
  newCompanyId: 'COMPANY_456',
  transferredBy: currentUserId,
);

// Передать автомобиль из корпоративного в личный гараж
await carService.transferCarToGarage(
  carId: 'CAR_123',
  newOwnerId: 'USER_789',
  newGarageId: 'personal_garage_789',     // Другой ОДИН гараж
  newGarageType: 'PERSONAL',
  newCompanyId: null,
  transferredBy: currentUserId,
);

// ❌ НЕЛЬЗЯ: Автомобиль не может быть в двух гаражах одновременно
// Только ОДИН garageId на автомобиль
```

### Получение автомобилей гаража

```dart
// Получить все автомобили ОДНОГО гаража
final personalCars = await carService.getCarsByGarage('personal_garage_123');
final companyCars = await carService.getCarsByGarage('COMPANY_garage_456');

// Каждый автомобиль имеет только ОДИН garageId
for (final car in personalCars) {
  print('${car.make} ${car.model} в гараже: ${car.garageId}');
  // Проверка валидности
  assert(car.validateGarageConsistency());
}
```

```dart
Future<void> addCarToCompanyGarage({
  required String companyId,
  required String garageId,
  required String make,
  required String model,
  required String licensePlate,
  required double dailyRate,
  required double monthlyRate,
}) async {
  // Получаем информацию о компании для определения владельца
  final orgDoc = await FirebaseFirestore.instance
      .collection('organizations')
      .doc(companyId)
      .get();
  
  final directorId = orgDoc.data()?['director_user_id'];

  final car = Car(
    id: FirebaseFirestore.instance.collection('cars').doc().id,
    ownerId: companyId, // Владелец - компания
    garageId: garageId,
    garageType: GarageType.company,
    companyId: companyId,
    make: make,
    model: model,
    licensePlate: licensePlate,
    status: CarStatus.available,
    dailyRate: dailyRate,
    monthlyRate: monthlyRate,
    photosLinks: [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await FirebaseFirestore.instance
      .collection('cars')
      .doc(car.id)
      .set(car.toFirestore());
}
```

### Выдача прав менеджеру на автомобиль

```dart
Future<void> grantCarPermissions({
  required String carId,
  required String managerId,
  required String grantedBy,
  bool canView = true,
  bool canEdit = false,
  bool canBook = false,
  bool canConfirmBooking = false,
  bool canViewFinancials = false,
}) async {
  final permission = CarPermissions(
    userId: managerId,
    carId: carId,
    canView: canView,
    canEdit: canEdit,
    canBook: canBook,
    canConfirmBooking: canConfirmBooking,
    canViewFinancials: canViewFinancials,
    grantedAt: DateTime.now(),
    grantedBy: grantedBy,
  );

  await FirebaseFirestore.instance
      .collection('cars')
      .doc(carId)
      .collection('permissions')
      .doc(managerId)
      .set(permission.toFirestore());
      
  print('Права на автомобиль выданы менеджеру: $managerId');
}
```

### Создание бронирования с расчетом комиссии

```dart
Future<void> createRental({
  required String carId,
  required String clientId,
  required String rentalUserId,
  required DateTime startDate,
  required DateTime endDate,
  required double dailyRate,
  required double depositAmount,
  double commissionRate = 0.15, // 15% комиссия по умолчанию
}) async {
  // Получаем информацию об автомобиле
  final carDoc = await FirebaseFirestore.instance
      .collection('cars')
      .doc(carId)
      .get();
  
  final carData = carDoc.data()!;
  final carOwnerId = carData['owner_id'];
  final managingCompanyId = carData['company_id'];
  
  // Рассчитываем финансы
  final days = endDate.difference(startDate).inDays + 1;
  final priceAmount = dailyRate * days;
  final commissionAmount = priceAmount * commissionRate;
  final ownerEarnings = priceAmount - commissionAmount;

  final rental = Rental(
    id: FirebaseFirestore.instance.collection('rentals').doc().id,
    carId: carId,
    clientId: clientId,
    rentalUserId: rentalUserId,
    carOwnerId: carOwnerId,
    managingCompanyId: managingCompanyId,
    startDate: startDate,
    endDate: endDate,
    status: RentalStatus.pending,
    priceAmount: priceAmount,
    commissionAmount: commissionAmount,
    depositAmount: depositAmount,
    ownerEarnings: ownerEarnings,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await FirebaseFirestore.instance
      .collection('rentals')
      .doc(rental.id)
      .set(rental.toFirestore());
      
  print('Бронирование создано: ${rental.id}');
  print('Сумма: $priceAmount, Комиссия: $commissionAmount, Владельцу: $ownerEarnings');
}
```

---

## 🔐 Управление правами доступа

### Использование AccessControl

```dart
import 'package:car_rental_manager/utils/access_control.dart';

final accessControl = AccessControl();

// Проверить доступ к автомобилю
Future<void> checkCarAccess(String userId, Car car, GlobalRole userRole) async {
  final canView = await accessControl.canViewCar(userId, car);
  final canEdit = await accessControl.canEditCar(userId, car, userRole);
  final canDelete = await accessControl.canDeleteCar(userId, car, userRole);
  
  print('Просмотр: $canView, Редактирование: $canEdit, Удаление: $canDelete');
}

// Проверить права на бронирование
Future<void> checkBookingAccess(String userId, Car car, GlobalRole userRole) async {
  final canBook = await accessControl.canCreateBooking(userId, car, userRole);
  final canConfirm = await accessControl.canConfirmBooking(userId, car, userRole);
  
  print('Бронирование: $canBook, Подтверждение: $canConfirm');
}

// Получить все доступные автомобили
Future<void> getUserCars(String userId, GlobalRole userRole) async {
  final cars = await accessControl.getAccessibleCars(userId, userRole);
  print('Доступно автомобилей: ${cars.length}');
}

// Получить все доступные аренды
Future<void> getUserRentals(String userId, GlobalRole userRole) async {
  final rentals = await accessControl.getAccessibleRentals(userId, userRole);
  print('Доступно аренд: ${rentals.length}');
}
```

---

## 🔄 Миграция существующих данных

### Скрипт миграции автомобилей

```dart
Future<void> migrateExistingCars() async {
  final firestore = FirebaseFirestore.instance;
  
  // Получаем все существующие автомобили
  final carsSnapshot = await firestore.collection('cars').get();
  
  for (final doc in carsSnapshot.docs) {
    final data = doc.data();
    
    // Определяем тип гаража на основе organizationId
    final organizationId = data['organization_id'];
    
    // Получаем информацию об организации
    final orgDoc = await firestore.collection('organizations').doc(organizationId).get();
    final directorId = orgDoc.data()?['director_user_id'];
    
    // Создаем корпоративный гараж, если его нет
    final garageId = 'COMPANY_garage_$organizationId';
    final garageDoc = await firestore.collection('garages').doc(garageId).get();
    
    if (!garageDoc.exists) {
      final garage = CompanyGarage(
        id: garageId,
        name: '${orgDoc.data()?['name']} - Автопарк',
        companyId: organizationId,
        directorId: directorId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await firestore.collection('garages').doc(garageId).set(garage.toFirestore());
    }
    
    // Обновляем автомобиль
    await firestore.collection('cars').doc(doc.id).update({
      'owner_id': organizationId,
      'garage_id': garageId,
      'garage_type': 'COMPANY',
      'company_id': organizationId,
    });
    
    print('Мигрирован автомобиль: ${doc.id}');
  }
  
  print('Миграция завершена!');
}
```

### Скрипт миграции аренд

```dart
Future<void> migrateExistingRentals() async {
  final firestore = FirebaseFirestore.instance;
  
  final rentalsSnapshot = await firestore.collection('rentals').get();
  
  for (final doc in rentalsSnapshot.docs) {
    final data = doc.data();
    
    // Получаем информацию об автомобиле
    final carId = data['car_id'];
    final carDoc = await firestore.collection('cars').doc(carId).get();
    final carData = carDoc.data()!;
    
    // Рассчитываем финансы если их нет
    final priceAmount = data['total_amount'] ?? data['price_amount'] ?? 0.0;
    final commissionAmount = data['commission_amount'] ?? 0.0;
    final ownerEarnings = priceAmount - commissionAmount;
    
    // Обновляем аренду
    await firestore.collection('rentals').doc(doc.id).update({
      'rental_user_id': data['manager_id'],
      'car_owner_id': carData['owner_id'],
      'managing_company_id': carData['company_id'],
      'price_amount': priceAmount,
      'owner_earnings': ownerEarnings,
    });
    
    print('Мигрирована аренда: ${doc.id}');
  }
  
  print('Миграция аренд завершена!');
}
```

---

## 📊 Отчетность и аналитика

### Получение финансовой статистики владельца

```dart
Future<Map<String, dynamic>> getOwnerFinancials(String ownerId) async {
  final firestore = FirebaseFirestore.instance;
  
  // Получаем все аренды автомобилей владельца
  final rentalsSnapshot = await firestore
      .collection('rentals')
      .where('car_owner_id', isEqualTo: ownerId)
      .where('status', whereIn: ['COMPLETED'])
      .get();
  
  double totalRevenue = 0;
  double totalCommissions = 0;
  double totalEarnings = 0;
  
  for (final doc in rentalsSnapshot.docs) {
    final data = doc.data();
    totalRevenue += (data['price_amount'] ?? 0.0).toDouble();
    totalCommissions += (data['commission_amount'] ?? 0.0).toDouble();
    totalEarnings += (data['owner_earnings'] ?? 0.0).toDouble();
  }
  
  return {
    'total_rentals': rentalsSnapshot.docs.length,
    'total_revenue': totalRevenue,
    'total_commissions': totalCommissions,
    'total_earnings': totalEarnings,
    'commission_rate': totalRevenue > 0 ? (totalCommissions / totalRevenue * 100) : 0,
  };
}
```

### Получение статистики менеджера

```dart
Future<Map<String, dynamic>> getManagerStatistics(String managerId) async {
  final firestore = FirebaseFirestore.instance;
  
  final rentalsSnapshot = await firestore
      .collection('rentals')
      .where('rental_user_id', isEqualTo: managerId)
      .get();
  
  double totalCommissions = 0;
  int completedRentals = 0;
  
  for (final doc in rentalsSnapshot.docs) {
    final data = doc.data();
    if (data['status'] == 'COMPLETED') {
      completedRentals++;
      totalCommissions += (data['commission_amount'] ?? 0.0).toDouble();
    }
  }
  
  return {
    'total_rentals': rentalsSnapshot.docs.length,
    'completed_rentals': completedRentals,
    'total_commissions': totalCommissions,
  };
}
```

---

## 🚀 Рекомендации по внедрению

1. **Поэтапная миграция**: Начните с создания гаражей для существующих автомобилей
2. **Тестирование прав доступа**: Проверьте все сценарии с помощью `AccessControl`
3. **Обновление UI**: Адаптируйте интерфейс для работы с новыми полями
4. **Обратная совместимость**: Сохраняйте старые поля с пометкой `@Deprecated`
5. **Мониторинг**: Отслеживайте корректность расчета комиссий

---

## 📞 Поддержка

Для вопросов и предложений обращайтесь к документации проекта или создавайте issues в репозитории.
