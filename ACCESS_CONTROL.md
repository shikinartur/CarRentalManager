# Система управления доступом (Access Control System)

## 📋 Обзор

Документ описывает полную систему управления доступом в приложении CarRentalManager, включая права на просмотр отчетов, контакты клиентов, делегирование прав директора и управление компаниями.

---

## 1. Доступ к отчетам по аренде (RENT)

### Кто имеет доступ:

1. **Владелец автопарка (гаража)**, которому принадлежит автомобиль
   - Проверяется через `car.garageId` → `garage.ownerId`

2. **Компания**, которой принадлежит автомобиль
   - Проверяется через `car.companyId`
   - Доступ имеют:
     - DIRECTOR компании
     - Менеджеры с делегированными правами директора

3. **Менеджер, создавший аренду**
   - Проверяется через `rental.rentalUserId`

### Важно:
- К аренде привязана **компания** (`managingCompanyId`), а НЕ директор лично
- Это обеспечивает корпоративный доступ к отчетам

### Код проверки:
```dart
final canView = await AccessControl().canViewRentalReport(userId, rental);
```

---

## 2. Доступ к контактным данным клиентов

### 2.1. Модель Client

Каждый клиент имеет поле `createdBy` - ID пользователя, создавшего клиента.

```dart
class Client {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String createdBy;  // ID создателя
  // ...
}
```

### 2.2. Права доступа к контактам клиента

#### Кто имеет доступ:

1. **Создатель клиента** - всегда имеет полный доступ

2. **Пользователи, которым предоставлен доступ**
   - Создатель может поделиться с любым пользователем

3. **Компании, которым предоставлен доступ**
   - Создатель может поделиться с компанией
   - Тогда доступ получает **только директор компании** (не все сотрудники)

### 2.3. Модель ClientPermissions

```dart
class ClientPermissions {
  final String clientId;
  final String? userId;      // Доступ для конкретного пользователя
  final String? companyId;   // Доступ для всей компании
  final DateTime grantedAt;
  final String grantedBy;    // ID создателя
}
```

**Firestore структура:**
```
clients/{clientId}/permissions/{permissionId}
  - client_id: string
  - user_id?: string         // Либо userId
  - company_id?: string      // Либо companyId
  - granted_by: string
  - granted_at: timestamp
```

### 2.4. Примеры использования

#### Проверить доступ к контактам:
```dart
final canView = await AccessControl().canViewClientContacts(userId, clientId);
```

#### Предоставить доступ пользователю:
```dart
await AccessControl().grantClientAccessToUser(
  granterId: creatorId,
  clientId: clientId,
  targetUserId: managerId,
);
```

#### Предоставить доступ компании:
```dart
await AccessControl().grantClientAccessToCompany(
  granterId: creatorId,
  clientId: clientId,
  targetCompanyId: companyId,
);
```

---

## 3. Доступ к контактам компании

### Правила:

1. **Директор компании** имеет доступ ко всем контактам компании

2. **Директор может поделиться контактом**:
   - С любым пользователем
   - С другой компанией (тогда доступ получит директор той компании)

### Использование:

Система контактов компании аналогична контактам клиентов. Можно использовать ту же модель `ClientPermissions`, заменив `clientId` на `companyContactId`.

---

## 4. Делегирование прав директора

### 4.1. Концепция

Директор может передать менеджеру **ВСЕ свои права роли DIRECTOR**, кроме закрытия компании.

### 4.2. Делегируемые права:

✅ **Передаются:**
- Управление автомобилями компании (добавление, редактирование, удаление)
- Выдача прав доступа к автомобилям другим менеджерам
- Управление контактами компании
- Просмотр всех аренд компании
- Финансовая отчетность компании
- Создание/редактирование броней и заявок

❌ **НЕ передается:**
- Закрытие компании (только создатель компании)

### 4.3. Модель DirectorDelegation

```dart
class DirectorDelegation {
  final String companyId;
  final String userId;      // ID менеджера с правами
  final DateTime grantedAt;
  final String grantedBy;   // ID директора
  final bool isActive;
}
```

**Firestore структура:**
```
companies/{companyId}/director_delegations/{userId}
  - company_id: string
  - user_id: string
  - granted_by: string
  - granted_at: timestamp
  - is_active: boolean
```

### 4.4. Примеры использования

#### Делегировать права:
```dart
await AccessControl().delegateDirectorRights(
  directorId: directorId,
  managerId: managerId,
  companyId: companyId,
);
```

#### Отозвать делегированные права:
```dart
await AccessControl().revokeDelegatedDirectorRights(
  directorId: directorId,
  managerId: managerId,
  companyId: companyId,
);
```

#### Проверить делегированные права:
```dart
final hasDelegation = await AccessControl().hasDelegatedDirectorRights(
  userId, 
  companyId,
);
```

---

## 6. Отмена бронирования (Rental)

### 6.1. Правила отмены бронирования

1. **Менеджер может отменить свою бронь**
   - Проверяется `rental.rentalUserId == currentUserId`
   - Отменяет без дополнительных уведомлений

2. **Директор НЕ может отменить бронь без уведомления менеджера**
   - Даже если компания управляет автомобилем
   - Даже если директор имеет полный доступ к отчетам
   - **Обязательное условие**: должен уведомить менеджера (`rental.rentalUserId`)

3. **Владелец автомобиля может отменить бронь**
   - Проверяется `rental.carOwnerId == currentUserId`
   - С обязательным уведомлением менеджера

### 6.2. Модель RentalCancellation

Для отслеживания отмен и уведомлений:

```dart
class RentalCancellation {
  final String id;
  final String rentalId;
  final String cancelledBy;      // ID пользователя, отменившего
  final String reason;            // Причина отмены
  final DateTime cancelledAt;
  final bool managerNotified;     // Был ли уведомлен менеджер
  final DateTime? notifiedAt;     // Когда отправлено уведомление
  final String? notificationMessage; // Текст уведомления
}
```

**Firestore структура:**
```
rental_cancellations/{cancellationId}
  - rental_id: string
  - cancelled_by: string
  - reason: string
  - cancelled_at: timestamp
  - manager_notified: boolean
  - notified_at?: timestamp
  - notification_message?: string
```

### 6.3. Workflow отмены бронирования

#### Менеджер отменяет свою бронь:
```dart
Future<void> cancelRentalAsManager(String rentalId, String reason) async {
  final rental = await getRental(rentalId);
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  // Проверка прав
  if (rental.rentalUserId != currentUserId) {
    throw Exception('Вы можете отменить только свои бронирования');
  }
  
  // Отмена без дополнительных уведомлений
  await updateRentalStatus(rentalId, RentalStatus.cancelled);
  
  // Логирование отмены
  await createCancellationRecord(
    rentalId: rentalId,
    cancelledBy: currentUserId,
    reason: reason,
    managerNotified: true, // Сам менеджер
  );
}
```

#### Директор отменяет бронь (с обязательным уведомлением):
```dart
Future<void> cancelRentalAsDirector(
  String rentalId, 
  String reason,
  String notificationMessage,
) async {
  final rental = await getRental(rentalId);
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  // Проверка: является ли директором компании
  final isDirector = await AccessControl().isCompanyDirector(
    currentUserId,
    rental.managingCompanyId,
  );
  
  if (!isDirector) {
    throw Exception('Только директор компании может отменить эту бронь');
  }
  
  // Проверка: не тот же пользователь, что создал бронь
  if (rental.rentalUserId == currentUserId) {
    // Это его собственная бронь, уведомление не требуется
    await cancelRentalAsManager(rentalId, reason);
    return;
  }
  
  // ОБЯЗАТЕЛЬНО: отправить уведомление менеджеру
  await sendCancellationNotification(
    toUserId: rental.rentalUserId,
    fromUserId: currentUserId,
    rentalId: rentalId,
    message: notificationMessage,
  );
  
  // Отмена брони
  await updateRentalStatus(rentalId, RentalStatus.cancelled);
  
  // Логирование отмены с отметкой об уведомлении
  await createCancellationRecord(
    rentalId: rentalId,
    cancelledBy: currentUserId,
    reason: reason,
    managerNotified: true,
    notificationMessage: notificationMessage,
  );
}
```

#### Владелец автомобиля отменяет бронь:
```dart
Future<void> cancelRentalAsOwner(
  String rentalId,
  String reason,
  String notificationMessage,
) async {
  final rental = await getRental(rentalId);
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  // Проверка прав владельца
  if (rental.carOwnerId != currentUserId) {
    throw Exception('Только владелец автомобиля может отменить эту бронь');
  }
  
  // ОБЯЗАТЕЛЬНО: уведомить менеджера
  await sendCancellationNotification(
    toUserId: rental.rentalUserId,
    fromUserId: currentUserId,
    rentalId: rentalId,
    message: notificationMessage,
  );
  
  // Отмена брони
  await updateRentalStatus(rentalId, RentalStatus.cancelled);
  
  // Логирование
  await createCancellationRecord(
    rentalId: rentalId,
    cancelledBy: currentUserId,
    reason: reason,
    managerNotified: true,
    notificationMessage: notificationMessage,
  );
}
```

### 6.4. Проверка прав на отмену

```dart
class AccessControl {
  /// Проверить, может ли пользователь отменить бронь
  Future<bool> canCancelRental(String userId, Rental rental) async {
    // 1. Менеджер, создавший бронь
    if (rental.rentalUserId == userId) {
      return true;
    }
    
    // 2. Директор компании (с обязательным уведомлением)
    if (rental.managingCompanyId != null) {
      final isDirector = await isCompanyDirector(
        userId,
        rental.managingCompanyId!,
      );
      if (isDirector) {
        return true; // Но с уведомлением!
      }
    }
    
    // 3. Владелец автомобиля (с обязательным уведомлением)
    if (rental.carOwnerId == userId) {
      return true; // Но с уведомлением!
    }
    
    return false;
  }
  
  /// Требуется ли уведомление менеджера при отмене
  bool requiresManagerNotification(String userId, Rental rental) {
    // Если сам менеджер отменяет - уведомление не требуется
    if (rental.rentalUserId == userId) {
      return false;
    }
    
    // Во всех остальных случаях - требуется
    return true;
  }
}
```

---

## 8. Агенты и система заявок на бронирование

### 8.1. Роль AGENT

**AGENT** - это начальная роль для новых сотрудников компании. Агенты формируют заявки на бронирование, но не могут создавать подтвержденные бронирования напрямую.

#### Права агента:
- ✅ Создание **заявок** на бронирование (требуют подтверждения)
- ✅ Работа с клиентами (создание, просмотр, редактирование)
- ✅ Просмотр автомобилей компании
- ✅ Просмотр своих заявок и их статуса
- ❌ Мгновенное бронирование (нет прав)
- ❌ Подтверждение заявок других агентов
- ❌ Отмена подтвержденных бронирований

### 8.2. Иерархия ролей

```
OWNER > DIRECTOR > MANAGER > AGENT > GUEST
```

**Ключевое различие:**
- **MANAGER** - мгновенное бронирование (без подтверждения)
- **AGENT** - создание заявок (требуют подтверждения)

### 8.3. Модель BookingRequest

```dart
enum BookingRequestStatus {
  pending,    // Ожидает подтверждения
  approved,   // Подтверждена → создано Rental
  rejected,   // Отклонена
  cancelled   // Отменена агентом
}

class BookingRequest {
  final String id;
  final String carId;
  final String clientId;
  final String createdBy;        // ID агента
  final String? companyId;       // Компания-контекст
  
  final DateTime startDate;
  final DateTime endDate;
  final BookingRequestStatus status;
  
  // Финансы (предложенные агентом)
  final double proposedPrice;
  final double proposedDeposit;
  
  // Рассмотрение заявки
  final String? reviewedBy;      // Кто подтвердил/отклонил
  final DateTime? reviewedAt;
  final String? reviewNote;      // Комментарий
  final String? rentalId;        // ID созданного Rental (если approved)
  
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Firestore структура:**
```
booking_requests/{requestId}
  - car_id: string
  - client_id: string
  - created_by: string (agent userId)
  - company_id?: string
  - request_group_id: string (группа связанных заявок)
  - start_date: timestamp
  - end_date: timestamp
  - status: string (PENDING/APPROVED/CONFIRMED/REJECTED/CANCELLED/AUTO_ANNULLED)
  - proposed_price: number
  - proposed_deposit: number
  
  # Подтверждение менеджером/директором
  - reviewed_by?: string (manager/director userId)
  - reviewed_at?: timestamp
  - review_note?: string
  
  # Финальный выбор агента
  - confirmed_by?: string (agent userId, должен быть = created_by)
  - confirmed_at?: timestamp
  - rental_id?: string (ID созданной брони)
  
  # Автоматическая аннуляция
  - annulled_by?: string (ID заявки, которая была выбрана)
  - annulled_at?: timestamp
  
  - notes?: string
  - created_at: timestamp
  - updated_at: timestamp
```

**Статусы заявки:**
- `PENDING` - Ожидает подтверждения менеджером/директором
- `APPROVED` - Подтверждена, ждет финального выбора агента
- `CONFIRMED` - Выбрана агентом → создана бронь
- `REJECTED` - Отклонена менеджером/директором
- `CANCELLED` - Отменена агентом
- `AUTO_ANNULLED` - Автоматически аннулирована (агент выбрал другую заявку)

### 8.4. Специальные права: Подтверждение заявок

Директор может выдать менеджеру **специальное право** подтверждать заявки агентов.

#### Модель UserPermission

```dart
enum PermissionType {
  approveBookingRequests,  // Подтверждать заявки на бронирование
  manageTeam,              // Управлять командой
  viewFinancials           // Просматривать финансы
}

class UserPermission {
  final String id;
  final String userId;
  final String? companyId;
  final String? garageId;
  final PermissionType permissionType;
  final String grantedBy;       // Директор
  final DateTime grantedAt;
  final bool isActive;
  final DateTime? expiresAt;    // Опционально
}
```

**Firestore структура:**
```
user_permissions/{permissionId}
  - user_id: string
  - company_id?: string
  - garage_id?: string
  - permission_type: string (APPROVE_BOOKING_REQUESTS)
  - granted_by: string (director userId)
  - granted_at: timestamp
  - is_active: boolean
  - expires_at?: timestamp
```

### 8.5. Кто может подтверждать заявки

1. **DIRECTOR** - всегда может подтверждать заявки компании
2. **MANAGER с правом** - если директор выдал `approveBookingRequests`
3. **OWNER** - если заявка на его автомобиль

Код проверки:
```dart
Future<bool> canApproveBookingRequest(
  String userId,
  BookingRequest request,
) async {
  // 1. Проверить роль директора в компании
  final isDirector = await UserRoleService().isCompanyDirector(
    userId,
    request.companyId!,
  );
  if (isDirector) return true;
  
  // 2. Проверить, есть ли право у менеджера
  final hasPermission = await hasUserPermission(
    userId: userId,
    companyId: request.companyId,
    permissionType: PermissionType.approveBookingRequests,
  );
  if (hasPermission) return true;
  
  // 3. Проверить, владелец ли автомобиля
  final car = await getCar(request.carId);
  if (car.ownerId == userId) return true;
  
  return false;
}
```

### 8.6. Workflow: Множественные заявки

#### Принцип работы:

1. **Агент создает несколько заявок** на разные машины (одна сессия поиска)
   - Все заявки получают один `requestGroupId`
   - Status: `PENDING`

2. **Менеджеры/директора подтверждают заявки**
   - Каждый может подтвердить независимо
   - Status: `PENDING` → `APPROVED`
   - Машина временно блокируется

3. **Агент выбирает одну заявку** из подтвержденных
   - Status выбранной: `APPROVED` → `CONFIRMED`
   - Создается `Rental`

4. **Автоматическая аннуляция остальных заявок**
   - Все другие заявки из группы: Status → `AUTO_ANNULLED`
   - Машины снова становятся доступными

#### Схема:
```
АГЕНТ создает 3 заявки для клиента:
┌─────────────────────────────────────┐
│ RequestGroup: "group_abc123"        │
├─────────────────────────────────────┤
│ Request 1: Car A (PENDING)          │
│ Request 2: Car B (PENDING)          │
│ Request 3: Car C (PENDING)          │
└─────────────────────────────────────┘

МЕНЕДЖЕРЫ подтверждают:
┌─────────────────────────────────────┐
│ Request 1: Car A (APPROVED) ✓       │ ← Менеджер 1
│ Request 2: Car B (PENDING)          │
│ Request 3: Car C (APPROVED) ✓       │ ← Менеджер 2
└─────────────────────────────────────┘

АГЕНТ выбирает Request 1:
┌─────────────────────────────────────┐
│ Request 1: Car A (CONFIRMED) → 📋   │ ← Создана бронь
│ Request 2: Car B (PENDING)          │ ← Осталась в ожидании
│ Request 3: Car C (AUTO_ANNULLED) ❌ │ ← Аннулирована
└─────────────────────────────────────┘
        Car C снова доступна!
```

### 8.7. Workflow: Создание группы заявок агентом

```dart
Future<List<String>> createBookingRequestsAsAgent({
  required List<String> carIds,        // Несколько машин
  required String clientId,
  required DateTime startDate,
  required DateTime endDate,
  required double proposedPrice,
  required double proposedDeposit,
  String? notes,
}) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final requestGroupId = FirebaseFirestore.instance
      .collection('booking_requests')
      .doc()
      .id; // Общий ID для группы
  
  final requestIds = <String>[];
  
  // Создать заявку на каждую машину
  for (final carId in carIds) {
    final requestId = FirebaseFirestore.instance
        .collection('booking_requests')
        .doc()
        .id;
    
    final request = BookingRequest(
      id: requestId,
      carId: carId,
      clientId: clientId,
      createdBy: currentUserId,
      companyId: companyId,
      requestGroupId: requestGroupId, // ОБЩИЙ ID
      startDate: startDate,
      endDate: endDate,
      status: BookingRequestStatus.pending,
      proposedPrice: proposedPrice,
      proposedDeposit: proposedDeposit,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await FirebaseFirestore.instance
        .collection('booking_requests')
        .doc(requestId)
        .set(request.toFirestore());
    
    requestIds.add(requestId);
  }
  
  // Уведомить директора/менеджеров о новых заявках
  await notifyApprovers(requestGroupId, requestIds);
  
  return requestIds;
}
```

### 8.8. Workflow: Подтверждение заявки менеджером

```dart
Future<void> createBookingRequestAsAgent({
  required String carId,
  required String clientId,
  required DateTime startDate,
  required DateTime endDate,
  required double proposedPrice,
  required double proposedDeposit,
  String? notes,
}) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  // 1. Проверить роль агента
  final role = await UserRoleService().getUserRoleInCompany(
    currentUserId,
    companyId,
  );
  
  if (role == null || !role.roleType.canCreateBookingRequest) {
    throw Exception('Нет прав создавать заявки');
  }
  
  // 2. Создать заявку
  final requestId = FirebaseFirestore.instance
      .collection('booking_requests')
      .doc()
      .id;
  
  final request = BookingRequest(
    id: requestId,
    carId: carId,
    clientId: clientId,
    createdBy: currentUserId,
    companyId: companyId,
    startDate: startDate,
    endDate: endDate,
    status: BookingRequestStatus.pending,
    proposedPrice: proposedPrice,
    proposedDeposit: proposedDeposit,
    notes: notes,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  
  await FirebaseFirestore.instance
      .collection('booking_requests')
      .doc(requestId)
      .set(request.toFirestore());
  
  // 3. Уведомить директора/менеджеров о новой заявке
  await notifyApprovers(request);
}
```

### 8.7. Workflow: Подтверждение заявки менеджером (НЕ создает бронь!)

```dart
Future<void> approveBookingRequest(
  String requestId,
  {String? reviewNote}
) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final request = await getBookingRequest(requestId);
  
  // 1. Проверить права
  final canApprove = await canApproveBookingRequest(
    currentUserId,
    request,
  );
  
  if (!canApprove) {
    throw Exception('Нет прав подтверждать эту заявку');
  }
  
  // 2. Обновить заявку (status: PENDING → APPROVED)
  // НЕ создаем бронирование! Ждем выбора агента
  await FirebaseFirestore.instance
      .collection('booking_requests')
      .doc(requestId)
      .update({
    'status': BookingRequestStatus.approved.value,
    'reviewed_by': currentUserId,
    'reviewed_at': FieldValue.serverTimestamp(),
    'review_note': reviewNote,
    'updated_at': FieldValue.serverTimestamp(),
  });
  
  // 3. Уведомить агента о подтверждении
  await notifyAgent(request.createdBy, request);
}
```

### 8.8. Workflow: Финальный выбор агента (создает бронь + аннулирует остальные)

```dart
Future<void> confirmBookingRequestByAgent(
  String requestId,
) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final request = await getBookingRequest(requestId);
  
  // 1. Проверить права
  if (request.createdBy != currentUserId) {
    throw Exception('Только автор заявки может её подтвердить');
  }
  
  if (request.status != BookingRequestStatus.approved) {
    throw Exception('Заявка ещё не подтверждена менеджером');
  }
  
  // 2. Создать бронирование
  final rental = await createRentalFromRequest(request, currentUserId);
  
  // 3. Обновить выбранную заявку (status: APPROVED → CONFIRMED)
  await FirebaseFirestore.instance
      .collection('booking_requests')
      .doc(requestId)
      .update({
    'status': BookingRequestStatus.confirmed.value,
    'confirmed_by': currentUserId,
    'confirmed_at': FieldValue.serverTimestamp(),
    'rental_id': rental.id,
    'updated_at': FieldValue.serverTimestamp(),
  });
  
  // 4. АННУЛИРОВАТЬ ВСЕ ОСТАЛЬНЫЕ ЗАЯВКИ ИЗ ГРУППЫ
  await annulOtherRequestsInGroup(
    requestGroupId: request.requestGroupId,
    excludeRequestId: requestId,
    selectedRequestId: requestId,
  );
  
  // 5. Уведомить менеджеров об отмене их заявок
  await notifyManagersAboutAnnulment(request.requestGroupId, requestId);
}

/// Аннулировать все остальные заявки из группы
Future<void> annulOtherRequestsInGroup({
  required String requestGroupId,
  required String excludeRequestId,
  required String selectedRequestId,
}) async {
  // Найти все заявки группы
  final snapshot = await FirebaseFirestore.instance
      .collection('booking_requests')
      .where('request_group_id', isEqualTo: requestGroupId)
      .where('id', isNotEqualTo: excludeRequestId)
      .get();
  
  final batch = FirebaseFirestore.instance.batch();
  
  for (final doc in snapshot.docs) {
    final request = BookingRequest.fromFirestore(doc);
    
    // Аннулировать только PENDING и APPROVED заявки
    if (request.status == BookingRequestStatus.pending ||
        request.status == BookingRequestStatus.approved) {
      
      batch.update(doc.reference, {
        'status': BookingRequestStatus.autoAnnulled.value,
        'annulled_by': selectedRequestId,
        'annulled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }
  
  await batch.commit();
  
  // Машины автоматически становятся доступными
}
```

### 8.9. Workflow: Отклонение заявки

```dart
Future<void> rejectBookingRequest(
  String requestId,
  String reason,
) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final request = await getBookingRequest(requestId);
  
  // 1. Проверить права
  final canApprove = await canApproveBookingRequest(
    currentUserId,
    request,
  );
  
  if (!canApprove) {
    throw Exception('Нет прав отклонять эту заявку');
  }
  
  // 2. Обновить заявку
  await FirebaseFirestore.instance
      .collection('booking_requests')
      .doc(requestId)
      .update({
    'status': BookingRequestStatus.rejected.value,
    'reviewed_by': currentUserId,
    'reviewed_at': FieldValue.serverTimestamp(),
    'review_note': reason,
    'updated_at': FieldValue.serverTimestamp(),
  });
  
  // 3. Уведомить агента об отклонении
  await notifyAgentRejection(request.createdBy, reason);
}
```

### 8.9. Выдача права подтверждения менеджеру

```dart
Future<void> grantApprovalPermissionToManager({
  required String directorId,
  required String managerId,
  required String companyId,
  DateTime? expiresAt,
}) async {
  // 1. Проверить, что текущий пользователь - директор
  final isDirector = await UserRoleService().isCompanyDirector(
    directorId,
    companyId,
  );
  
  if (!isDirector) {
    throw Exception('Только директор может выдавать права');
  }
  
  // 2. Проверить, что целевой пользователь - менеджер
  final managerRole = await UserRoleService().getUserRoleInCompany(
    managerId,
    companyId,
  );
  
  if (managerRole?.roleType != RoleType.manager) {
    throw Exception('Можно выдать право только менеджеру');
  }
  
  // 3. Создать разрешение
  final permissionId = FirebaseFirestore.instance
      .collection('user_permissions')
      .doc()
      .id;
  
  final permission = UserPermission(
    id: permissionId,
    userId: managerId,
    companyId: companyId,
    permissionType: PermissionType.approveBookingRequests,
    grantedBy: directorId,
    grantedAt: DateTime.now(),
    isActive: true,
    expiresAt: expiresAt,
  );
  
  await FirebaseFirestore.instance
      .collection('user_permissions')
      .doc(permissionId)
      .set(permission.toFirestore());
}
```

### 8.10. UI для заявок

#### Список всех заявок агента (с группировкой):
```dart
Widget buildAgentRequestsList(String agentId) {
  return StreamBuilder<List<BookingRequest>>(
    stream: BookingRequestService().watchRequestsByAgent(agentId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator();
      
      // Группировать по requestGroupId
      final groups = <String, List<BookingRequest>>{};
      for (final request in snapshot.data!) {
        groups.putIfAbsent(request.requestGroupId, () => []).add(request);
      }
      
      return ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final groupId = groups.keys.elementAt(index);
          final requests = groups[groupId]!;
          
          // Определить статус группы
          final hasConfirmed = requests.any((r) => r.isConfirmed);
          final approvedRequests = requests.where((r) => r.isApproved).toList();
          final pendingCount = requests.where((r) => r.isPending).length;
          
          return RequestGroupCard(
            groupId: groupId,
            requests: requests,
            status: hasConfirmed ? 'Забронировано' : 
                    approvedRequests.isNotEmpty ? 'Готово к выбору (${ approvedRequests.length})' :
                    'Ожидание ($pendingCount)',
            onSelect: hasConfirmed ? null : 
                     approvedRequests.isEmpty ? null :
                     () => showSelectRequestDialog(approvedRequests),
          );
        },
      );
    },
  );
}

/// Диалог выбора одной из подтвержденных заявок
Future<void> showSelectRequestDialog(List<BookingRequest> approvedRequests) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Выберите автомобиль'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: approvedRequests.map((request) {
          return ListTile(
            title: Text('Car: ${request.carId}'),
            subtitle: Text('Подтверждена: ${request.reviewedBy}'),
            trailing: ElevatedButton(
              child: Text('Выбрать'),
              onPressed: () async {
                await confirmRequestByAgent(request.id);
                Navigator.pop(context);
              },
            ),
          );
        }).toList(),
      ),
    ),
  );
}
```

#### Карточка группы заявок с индикацией статусов:
```dart
class RequestGroupCard extends StatelessWidget {
  final String groupId;
  final List<BookingRequest> requests;
  final String status;
  final VoidCallback? onSelect;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text('Заявка от ${requests.first.createdAt.format()}'),
        subtitle: Text('Клиент: ${requests.first.clientId} • $status'),
        trailing: onSelect != null 
            ? ElevatedButton(
                child: Text('Выбрать →'),
                onPressed: onSelect,
              )
            : null,
        children: requests.map((request) {
          return ListTile(
            leading: _getStatusIcon(request.status),
            title: Text('Car: ${request.carId}'),
            subtitle: Text(_getStatusText(request)),
            trailing: _getActionButton(request),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _getStatusIcon(BookingRequestStatus status) {
    switch (status) {
      case BookingRequestStatus.pending:
        return Icon(Icons.hourglass_empty, color: Colors.orange);
      case BookingRequestStatus.approved:
        return Icon(Icons.check_circle, color: Colors.green);
      case BookingRequestStatus.confirmed:
        return Icon(Icons.done_all, color: Colors.blue);
      case BookingRequestStatus.rejected:
        return Icon(Icons.cancel, color: Colors.red);
      case BookingRequestStatus.cancelled:
        return Icon(Icons.close, color: Colors.grey);
      case BookingRequestStatus.autoAnnulled:
        return Icon(Icons.auto_delete, color: Colors.grey);
    }
  }
  
  String _getStatusText(BookingRequest request) {
    switch (request.status) {
      case BookingRequestStatus.pending:
        return 'Ожидает подтверждения';
      case BookingRequestStatus.approved:
        return 'Подтверждена ${request.reviewedBy} • Можно выбрать!';
      case BookingRequestStatus.confirmed:
        return 'Выбрана → Бронь создана';
      case BookingRequestStatus.rejected:
        return 'Отклонена: ${request.reviewNote}';
      case BookingRequestStatus.cancelled:
        return 'Отменена вами';
      case BookingRequestStatus.autoAnnulled:
        return 'Аннулирована (выбрана другая машина)';
    }
  }
  
  Widget? _getActionButton(BookingRequest request) {
    if (request.isPending) {
      return TextButton(
        child: Text('Отменить'),
        onPressed: () => cancelRequest(request.id),
      );
    }
    return null;
  }
}
```

#### Список заявок для директора/менеджера:
```dart
Widget buildPendingRequestsList() {
  return StreamBuilder<List<BookingRequest>>(
    stream: getPendingBookingRequestsStream(companyId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator();
      
      final requests = snapshot.data!;
      
      return ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          
          return BookingRequestCard(
            request: request,
            onApprove: () => approveBookingRequest(request.id),
            onReject: () => showRejectDialog(request.id),
          );
        },
      );
    },
  );
}
```

#### Форма создания множественных заявок для агента:
```dart
Widget buildCreateMultipleRequestsForm() {
  final selectedCars = <Car>[];
  
  return Form(
    key: _formKey,
    child: Column(
      children: [
        // Выбор нескольких машин
        MultiCarSelector(
          onSelected: (cars) => selectedCars.addAll(cars),
          selectedCars: selectedCars,
        ),
        
        ClientSelector(onSelected: (client) => _selectedClient = client),
        DateRangePicker(
          onSelected: (start, end) {
            _startDate = start;
            _endDate = end;
          },
        ),
        PriceInput(onChanged: (price) => _proposedPrice = price),
        DepositInput(onChanged: (deposit) => _proposedDeposit = deposit),
        NotesField(onChanged: (notes) => _notes = notes),
        
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate() && selectedCars.isNotEmpty) {
              // Создать заявки на все выбранные машины
              await BookingRequestService().createMultipleRequests(
                carIds: selectedCars.map((c) => c.id).toList(),
                clientId: _selectedClient!.id,
                createdBy: currentUserId,
                companyId: companyId,
                startDate: _startDate!,
                endDate: _endDate!,
                proposedPrice: _proposedPrice,
                proposedDeposit: _proposedDeposit,
                notes: _notes,
              );
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${selectedCars.length} заявок отправлено'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
          child: Text('Отправить ${selectedCars.length} заявок'),
        ),
      ],
    ),
  );
}
```

---

## 7. Система рейтингов и отзывов

### 7.1. Общие принципы

**Основное правило**: Пользователи могут оценивать только тех, с кем они **реально работали**.

Взаимодействия происходят через:
- **Бронирование (Rental)** - основная точка взаимодействия
- **Управление автомобилем** - владелец ↔ компания
- **Работа в компании** - директор ↔ менеджер

### 7.2. Модель Rating

```dart
enum RatingType {
  managerToOwner,      // Менеджер оценивает владельца авто
  ownerToManager,      // Владелец оценивает менеджера
  directorToManager,   // Директор оценивает менеджера
  managerToDirector,   // Менеджер оценивает директора
  companyToOwner,      // Компания оценивает владельца
  ownerToCompany,      // Владелец оценивает компанию
}

class Rating {
  final String id;
  final RatingType type;
  
  // Кто оценивает
  final String fromUserId;
  final String? fromCompanyId;  // Если оценка от компании
  
  // Кого оценивают
  final String toUserId;
  final String? toCompanyId;    // Если оценивают компанию
  
  // Контекст оценки
  final String? rentalId;       // Связь с бронированием
  final String? carId;          // Связь с автомобилем
  
  // Оценка
  final int rating;             // 1-5 звезд
  final String? review;         // Текст отзыва (опционально)
  final DateTime createdAt;
  
  // Видимость
  final bool isPublic;          // Публичный отзыв или приватный
}
```

**Firestore структура:**
```
ratings/{ratingId}
  - type: string
  - from_user_id: string
  - from_company_id?: string
  - to_user_id: string
  - to_company_id?: string
  - rental_id?: string
  - car_id?: string
  - rating: number (1-5)
  - review?: string
  - created_at: timestamp
  - is_public: boolean
```

### 7.3. Правила оценивания по категориям

#### 7.3.1. Менеджер ↔ Владелец автомобиля

**Когда можно оценить:**
- После завершения аренды (`RentalStatus.completed`)
- Менеджер создал бронь (`rental.rentalUserId`)
- Автомобиль принадлежит владельцу (`rental.carOwnerId`)

**Менеджер оценивает владельца:**
```dart
Future<bool> canRateOwner(String managerId, String ownerId, String rentalId) async {
  final rental = await getRental(rentalId);
  
  // Проверки:
  return rental.status == RentalStatus.completed &&
         rental.rentalUserId == managerId &&
         rental.carOwnerId == ownerId;
}
```

**Владелец оценивает менеджера:**
```dart
Future<bool> canRateManager(String ownerId, String managerId, String rentalId) async {
  final rental = await getRental(rentalId);
  
  // Проверки:
  return rental.status == RentalStatus.completed &&
         rental.carOwnerId == ownerId &&
         rental.rentalUserId == managerId;
}
```

#### 7.3.2. Директор ↔ Менеджер

**Когда можно оценить:**
- После завершения аренды, где участвовала их компания
- Директор управляет компанией
- Менеджер работал с автомобилями компании

**Директор оценивает менеджера:**
```dart
Future<bool> canDirectorRateManager(
  String directorId,
  String managerId,
  String companyId,
) async {
  // 1. Проверить, что это директор компании
  final isDirector = await AccessControl().isCompanyDirector(
    directorId,
    companyId,
  );
  
  if (!isDirector) return false;
  
  // 2. Проверить, что менеджер работал с компанией
  final rentals = await getRentalsWhere(
    rentalUserId: managerId,
    managingCompanyId: companyId,
    status: RentalStatus.completed,
  );
  
  return rentals.isNotEmpty;
}
```

**Менеджер оценивает директора:**
```dart
Future<bool> canManagerRateDirector(
  String managerId,
  String directorId,
  String companyId,
) async {
  // 1. Проверить, что это директор компании
  final isDirector = await AccessControl().isCompanyDirector(
    directorId,
    companyId,
  );
  
  if (!isDirector) return false;
  
  // 2. Проверить, что менеджер работал с компанией
  final rentals = await getRentalsWhere(
    rentalUserId: managerId,
    managingCompanyId: companyId,
    status: RentalStatus.completed,
  );
  
  return rentals.isNotEmpty;
}
```

#### 7.3.3. Компания ↔ Владелец автомобиля

**Когда можно оценить:**
- Компания управляет автомобилем владельца
- Есть завершенные аренды с этим автомобилем

**Компания оценивает владельца:**
```dart
Future<bool> canCompanyRateOwner(
  String companyId,
  String ownerId,
  String carId,
) async {
  final car = await getCar(carId);
  
  // Проверки:
  // 1. Автомобиль принадлежит владельцу
  if (car.ownerId != ownerId) return false;
  
  // 2. Компания управляет автомобилем
  if (car.companyId != companyId) return false;
  
  // 3. Есть завершенные аренды
  final rentals = await getRentalsWhere(
    carId: carId,
    status: RentalStatus.completed,
  );
  
  return rentals.isNotEmpty;
}
```

**Владелец оценивает компанию:**
```dart
Future<bool> canOwnerRateCompany(
  String ownerId,
  String companyId,
  String carId,
) async {
  final car = await getCar(carId);
  
  // Проверки аналогичны canCompanyRateOwner
  return car.ownerId == ownerId &&
         car.companyId == companyId &&
         (await getRentalsWhere(
           carId: carId,
           status: RentalStatus.completed,
         )).isNotEmpty;
}
```

### 7.4. Агрегированные рейтинги

Для каждого пользователя и компании хранится агрегированный рейтинг:

```dart
class UserRatingStats {
  final String userId;
  
  // Как менеджер
  final double asManagerRating;
  final int asManagerReviewsCount;
  
  // Как владелец
  final double asOwnerRating;
  final int asOwnerReviewsCount;
  
  // Как директор
  final double asDirectorRating;
  final int asDirectorReviewsCount;
  
  final DateTime updatedAt;
}

class CompanyRatingStats {
  final String companyId;
  final double overallRating;
  final int reviewsCount;
  final DateTime updatedAt;
}
```

**Firestore структура:**
```
user_rating_stats/{userId}
  - user_id: string
  - as_manager_rating: number
  - as_manager_reviews_count: number
  - as_owner_rating: number
  - as_owner_reviews_count: number
  - as_director_rating: number
  - as_director_reviews_count: number
  - updated_at: timestamp

company_rating_stats/{companyId}
  - company_id: string
  - overall_rating: number
  - reviews_count: number
  - updated_at: timestamp
```

### 7.5. Workflow создания отзыва

```dart
Future<void> createRating({
  required RatingType type,
  required String fromUserId,
  String? fromCompanyId,
  required String toUserId,
  String? toCompanyId,
  String? rentalId,
  String? carId,
  required int rating,
  String? review,
  bool isPublic = true,
}) async {
  // 1. Проверить права на оценку
  final canRate = await _checkRatingPermission(
    type: type,
    fromUserId: fromUserId,
    toUserId: toUserId,
    rentalId: rentalId,
    carId: carId,
  );
  
  if (!canRate) {
    throw Exception('У вас нет прав оценить этого пользователя');
  }
  
  // 2. Проверить, не было ли уже оценки
  final existing = await _findExistingRating(
    type: type,
    fromUserId: fromUserId,
    toUserId: toUserId,
    rentalId: rentalId,
  );
  
  if (existing != null) {
    throw Exception('Вы уже оценили эту работу');
  }
  
  // 3. Создать отзыв
  final ratingId = FirebaseFirestore.instance.collection('ratings').doc().id;
  
  await FirebaseFirestore.instance
      .collection('ratings')
      .doc(ratingId)
      .set({
    'type': type.name,
    'from_user_id': fromUserId,
    'from_company_id': fromCompanyId,
    'to_user_id': toUserId,
    'to_company_id': toCompanyId,
    'rental_id': rentalId,
    'car_id': carId,
    'rating': rating,
    'review': review,
    'is_public': isPublic,
    'created_at': FieldValue.serverTimestamp(),
  });
  
  // 4. Обновить агрегированную статистику
  await _updateRatingStats(toUserId, toCompanyId, type);
}
```

### 7.6. UI для отзывов

#### После завершения аренды:
```dart
Future<void> showRatingPrompt(Rental rental) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  // Определить, кого можно оценить
  List<RatingTarget> targets = [];
  
  // Если я менеджер - могу оценить владельца
  if (rental.rentalUserId == currentUserId) {
    targets.add(RatingTarget(
      userId: rental.carOwnerId,
      type: RatingType.managerToOwner,
      title: 'Оцените владельца автомобиля',
    ));
  }
  
  // Если я владелец - могу оценить менеджера
  if (rental.carOwnerId == currentUserId) {
    targets.add(RatingTarget(
      userId: rental.rentalUserId,
      type: RatingType.ownerToManager,
      title: 'Оцените менеджера',
    ));
  }
  
  // Если я директор - могу оценить менеджера
  if (rental.managingCompanyId != null) {
    final isDirector = await AccessControl().isCompanyDirector(
      currentUserId,
      rental.managingCompanyId!,
    );
    
    if (isDirector && rental.rentalUserId != currentUserId) {
      targets.add(RatingTarget(
        userId: rental.rentalUserId,
        type: RatingType.directorToManager,
        title: 'Оцените работу менеджера',
      ));
    }
  }
  
  // Показать форму оценки
  if (targets.isNotEmpty) {
    return showDialog(
      context: context,
      builder: (context) => RatingDialog(
        targets: targets,
        rentalId: rental.id,
      ),
    );
  }
}
```

### 7.7. Отображение рейтинга

#### В профиле пользователя:
```dart
Widget buildUserRatingDisplay(String userId) {
  return FutureBuilder<UserRatingStats>(
    future: getUserRatingStats(userId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator();
      
      final stats = snapshot.data!;
      
      return Column(
        children: [
          if (stats.asManagerReviewsCount > 0)
            RatingRow(
              label: 'Как менеджер',
              rating: stats.asManagerRating,
              count: stats.asManagerReviewsCount,
            ),
          
          if (stats.asOwnerReviewsCount > 0)
            RatingRow(
              label: 'Как владелец',
              rating: stats.asOwnerRating,
              count: stats.asOwnerReviewsCount,
            ),
          
          if (stats.asDirectorReviewsCount > 0)
            RatingRow(
              label: 'Как директор',
              rating: stats.asDirectorRating,
              count: stats.asDirectorReviewsCount,
            ),
        ],
      );
    },
  );
}
```

### 7.8. Защита от злоупотреблений

1. **Один отзыв на одну аренду**: Нельзя оценить одного человека дважды за одну работу
2. **Только после завершения**: Отзыв можно оставить только после `RentalStatus.completed`
3. **Взаимная оценка необязательна**: Если владелец оценил менеджера, менеджер не обязан оценивать обратно
4. **Редактирование запрещено**: После создания отзыв нельзя изменить (можно только удалить через support)
5. **Публичность**: Пользователь может выбрать, будет ли отзыв публичным

---

## 6.5. UI для отмены бронирования

```dart
Future<void> showCancelRentalDialog(Rental rental) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final requiresNotification = AccessControl()
      .requiresManagerNotification(currentUserId, rental);
  
  if (requiresNotification) {
    // Показать форму с полем для уведомления
    return showDialog(
      context: context,
      builder: (context) => CancelRentalWithNotificationDialog(
        rental: rental,
        onConfirm: (reason, message) async {
          await cancelRentalAsDirector(
            rental.id,
            reason,
            message,
          );
        },
      ),
    );
  } else {
    // Простое подтверждение
    return showDialog(
      context: context,
      builder: (context) => CancelRentalDialog(
        rental: rental,
        onConfirm: (reason) async {
          await cancelRentalAsManager(rental.id, reason);
        },
      ),
    );
  }
}
```

---

## 5. Создание и закрытие компаний

### 5.1. Правила

1. **Любой пользователь может создать компанию**
   - Но только **одну** компанию

2. **Только создатель может закрыть компанию**
   - Даже менеджер с делегированными правами НЕ может закрыть компанию

### 5.2. Модель User (обновлена)

```dart
class AppUser {
  final String uid;
  final String? ownedCompanyId;  // ID созданной компании
  // ...
}
```

### 5.3. Проверки

#### Может ли создать компанию:
```dart
final canCreate = await AccessControl().canCreateCompany(userId);
// true если ownedCompanyId == null
```

#### Может ли закрыть компанию:
```dart
final canClose = await AccessControl().canCloseCompany(userId, companyId);
// true только если user.ownedCompanyId == companyId
```

### 5.4. Workflow создания компании

```dart
// 1. Проверить возможность создания
if (!await AccessControl().canCreateCompany(userId)) {
  throw Exception('Вы уже создали компанию');
}

// 2. Создать компанию
final companyId = await createCompany(name, userId);

// 3. Обновить пользователя
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'owned_company_id': companyId});
```

### 5.5. Workflow закрытия компании

```dart
// 1. Проверить права
if (!await AccessControl().canCloseCompany(userId, companyId)) {
  throw Exception('Только создатель может закрыть компанию');
}

// 2. Закрыть компанию
await closeCompany(companyId);

// 3. Обновить пользователя
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'owned_company_id': null});
```

---

## 📊 Диаграмма системы прав

```
┌─────────────────────────────────────────────────────────┐
│                    ПОЛЬЗОВАТЕЛЬ                          │
└────────┬────────────────────────────────────────────────┘
         │
         ├── СОЗДАЕТ КОМПАНИЮ (только одну)
         │   └── ownedCompanyId → может закрыть
         │
         ├── СОЗДАЕТ КЛИЕНТОВ
         │   └── createdBy → может поделиться контактами
         │       ├── С пользователем (userId)
         │       └── С компанией (companyId)
         │
         ├── РОЛЬ: DIRECTOR
         │   ├── Управляет компанией
         │   ├── Может делегировать права менеджеру
         │   ├── Выдает специальные права (подтверждение заявок)
         │   ├── Мгновенное бронирование
         │   ├── Подтверждает заявки агентов
         │   ├── Может отменять брони (с уведомлением)
         │   ├── Может оценивать менеджеров и агентов
         │   └── НЕ может: закрыть чужую компанию
         │
         ├── РОЛЬ: MANAGER
         │   ├── Мгновенное бронирование (без подтверждения)
         │   ├── Может получить право подтверждать заявки
         │   ├── Может получить делегированные права DIRECTOR
         │   ├── Создает аренды (rentalUserId)
         │   ├── Видит отчеты по своим арендам
         │   ├── Может оценивать владельцев и директоров
         │   └── Может отменять свои брони (без уведомления)
         │
         ├── РОЛЬ: AGENT
         │   ├── Создает ЗАЯВКИ на бронирование (не брони!)
         │   ├── Работает с клиентами
         │   ├── Видит статус своих заявок
         │   ├── Может оценивать директоров
         │   └── НЕ может: мгновенное бронирование, подтверждение заявок
         │
         ├── РОЛЬ: OWNER (Владелец автомобиля)
         │   ├── Владеет автомобилями
         │   ├── Видит отчеты по своим авто
         │   ├── Мгновенное бронирование на свои авто
         │   ├── Может оценивать менеджеров и компании
         │   └── Может отменять брони (с уведомлением)
         │
         └── КОМПАНИЯ
             ├── Управляет автомобилями владельцев
             ├── Получает комиссию с аренд
             ├── Может быть оценена владельцами
             └── Может оценивать владельцев
```

### Workflow: Создание бронирования

```
┌──────────┐    МГНОВЕННОЕ       ┌─────────────┐
│ DIRECTOR │───────────────────▶│   RENTAL    │
└──────────┘                     └─────────────┘
                                       ▲
┌──────────┐    МГНОВЕННОЕ            │
│ MANAGER  │──────────────────────────┤
└──────────┘                           │
                                       │
┌──────────┐    ЗАЯВКА         ┌──────┴──────┐
│  AGENT   │──────────────────▶│   REQUEST   │
└──────────┘                   └──────┬──────┘
                                      │
                                      │ Подтверждение
                          ┌───────────┴───────────┐
                          │                       │
                    ┌─────▼─────┐         ┌──────▼──────┐
                    │ DIRECTOR  │         │  MANAGER    │
                    │           │         │  (с правом) │
                    └───────────┘         └─────────────┘
                          │                       │
                          └───────────┬───────────┘
                                      │
                                      ▼
                              ┌─────────────┐
                              │   RENTAL    │
                              └─────────────┘
```

### Взаимодействия и рейтинги

```
МЕНЕДЖЕР ←─────────→ ВЛАДЕЛЕЦ
    │                    │
    │ После аренды:      │
    │ - Может оценить    │
    │ ←─────────────────→│
    │                    │
    ↓                    ↓
ДИРЕКТОР            КОМПАНИЯ
    │                    │
    │ Управляет          │ Управляет авто
    │ менеджерами        │ владельца
    │ и агентами         │
    │                    │
    │ Может оценить ←────┤
    │ менеджера/агента   │
    │                    │
    ↓                    │
AGENT                    │
    │                    │
    │ Создает заявки     │
    │ Может оценить ─────┘
    │ директора
    │
    └────────────────────┘
         Работают
         вместе
```

---

## 🔐 Матрица прав доступа

| Действие | Директор | Менеджер | Агент | Владелец авто | Компания |
|----------|----------|----------|-------|---------------|----------|
| **Мгновенное бронирование** | ✅ | ✅ | ❌ | ✅ | ❌ |
| **Создать заявку на бронь** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Подтвердить заявку** | ✅ (всегда) | ✅ (если право) | ❌ | ❌ | ❌ |
| **Просмотр отчета RENT** | ✅ (компании) | ✅ (свои аренды) | ✅ (свои заявки) | ✅ (свои авто) | ✅ |
| **Контакты клиента** | ✅ (если доступ) | ✅ (если создатель) | ✅ (если создатель) | ❌ | ❌ |
| **Отмена брони** | ✅ (с уведомлением) | ✅ (без уведомления) | ❌ | ✅ (с уведомлением) | ❌ |
| **Оценить владельца** | ❌ | ✅ (после аренды) | ❌ | ❌ | ✅ (если управляет) |
| **Оценить менеджера** | ✅ (после аренды) | ❌ | ❌ | ✅ (после аренды) | ❌ |
| **Оценить агента** | ✅ (если работал) | ✅ (если работал) | ❌ | ❌ | ❌ |
| **Оценить директора** | ❌ | ✅ (если работал) | ✅ (если работал) | ❌ | ❌ |
| **Оценить компанию** | ❌ | ❌ | ❌ | ✅ (если работал) | ❌ |
| **Делегирование прав** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Выдача спец. прав** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Закрытие компании** | ✅ (только свою) | ✅ (только свою) | ❌ | ❌ | ❌ |
| **Создание компании** | ✅ (если нет) | ✅ (если нет) | ✅ (если нет) | ✅ (если нет) | ❌ |

---

## 📝 Важные заметки

1. **Компания vs Директор**: Права привязаны к компании, а не к директору лично. Это обеспечивает корпоративный доступ.

2. **Одна компания на пользователя**: Ограничение предотвращает создание множества "пустых" компаний.

3. **Делегирование ≠ Передача владения**: Делегированный менеджер получает права, но не становится владельцем компании.

4. **Контакты клиентов - только директору**: Когда создатель делится контактами с компанией, доступ получает только директор компании, а не все сотрудники.

5. **Контакты как ресурс**: Контакты клиентов - это ценный ресурс, доступ к которому контролируется создателем.

6. **Закрытие компании - финальная операция**: Только создатель может закрыть компанию, это предотвращает случайное/злонамеренное удаление.

7. **Обязательное уведомление при отмене брони**: Директор или владелец автомобиля **не может** отменить бронь без уведомления менеджера, который её создал. Это защищает работу менеджеров и предотвращает конфликты.

8. **Менеджер управляет своими бронями**: Только менеджер, создавший бронь, может отменить её без дополнительных согласований.

9. **Рейтинги только после работы**: Оценить можно только тех, с кем реально работал через завершенные аренды. Это предотвращает фейковые отзывы.

10. **Множественные рейтинги**: Пользователь имеет отдельные рейтинги как менеджер, владелец и директор. Это дает полную картину о человеке в разных ролях.

11. **Взаимная оценка необязательна**: Если владелец оценил менеджера, менеджер не обязан оценивать обратно. Каждый решает сам.

12. **Отзывы неизменяемы**: После публикации отзыв нельзя редактировать. Это обеспечивает честность системы.

---

## 🔧 Примеры интеграции

### Проверка прав при просмотре отчета:

```dart
Future<Widget> buildRentalReport(String rentalId) async {
  final rental = await getRental(rentalId);
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  final canView = await AccessControl().canViewRentalReport(
    currentUserId, 
    rental,
  );
  
  if (!canView) {
    return Text('Нет доступа к отчету');
  }
  
  return RentalReportWidget(rental: rental);
}
```

### Предоставление доступа к клиенту:

```dart
Future<void> shareClientWithManager(String clientId, String managerId) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  final success = await AccessControl().grantClientAccessToUser(
    granterId: currentUserId,
    clientId: clientId,
    targetUserId: managerId,
  );
  
  if (success) {
    print('Доступ предоставлен');
  }
}
```

### Делегирование прав менеджеру:

```dart
Future<void> makeManagerActingDirector(String managerId, String companyId) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  final success = await AccessControl().delegateDirectorRights(
    directorId: currentUserId,
    managerId: managerId,
    companyId: companyId,
  );
  
  if (success) {
    print('Права делегированы. Менеджер теперь действует как директор.');
  }
}
```
