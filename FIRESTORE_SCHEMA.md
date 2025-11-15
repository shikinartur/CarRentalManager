/// Firestore Database Structure for Car Rental Manager
/// 
/// This document defines the complete database schema with role-based access control
/// and dual ownership model (Investor + Manager)

/**
 * КОЛЛЕКЦИИ ВЕРХНЕГО УРОВНЯ
 * ========================
 */

// ====================
// USERS Collection
// ====================
collection: users/{userId}
fields:
  - uid: String                      // Firebase Auth UID
  - email: String                    // Email пользователя
  - display_name: String             // Полное имя
  - global_role: String              // DIRECTOR | MANAGER | INVESTOR | GUEST
  - organizations: Array<String>     // Список ID организаций
  - created_at: Timestamp
  - updated_at: Timestamp

indexes:
  - email (ascending)
  - global_role (ascending)
  - organizations (array-contains)

security_rules:
  read: if request.auth != null && 
           (request.auth.uid == userId || 
            hasRole(request.auth.uid, 'DIRECTOR'))
  write: if request.auth != null && 
            (request.auth.uid == userId || 
             hasRole(request.auth.uid, 'DIRECTOR'))


// ====================
// ORGANIZATIONS (Companies) Collection
// ====================
collection: organizations/{orgId}
fields:
  - id: String                       // Уникальный ID (ORG_XXX)
  - name: String                     // Название компании
  - director_user_id: String         // ID пользователя-директора
  - is_active: Boolean               // Активна ли организация
  - created_at: Timestamp
  - updated_at: Timestamp

indexes:
  - director_user_id (ascending)
  - is_active (ascending)

security_rules:
  read: if request.auth != null && 
           (isDirector(request.auth.uid, orgId) || 
            hasAccessToOrg(request.auth.uid, orgId))
  write: if request.auth != null && 
            isDirector(request.auth.uid, orgId)


// ====================
// GARAGES Collection (Личные и Корпоративные)
// ====================
collection: garages/{garageId}
fields:
  - id: String                       // personal_garage_XXX или COMPANY_garage_XXX
  - type: String                     // PERSONAL | COMPANY
  - name: String                     // Название гаража
  - is_active: Boolean
  - created_at: Timestamp
  - updated_at: Timestamp
  
  // Для PERSONAL гаража (любой пользователь):
  - owner_id: String?                // USER_id владельца (INVESTOR, DIRECTOR, MANAGER, GUEST)
  - managing_company_id: String?     // COMPANY_id управляющей компании
  - commission_rate: Number?         // Процент комиссии управляющей компании
  
  // Для COMPANY гаража:
  - company_id: String?              // COMPANY_id владеющей компании
  - director_id: String?             // USER_id директора

indexes:
  - type (ascending)
  - owner_id (ascending)
  - managing_company_id (ascending)
  - company_id (ascending)
  - is_active (ascending)

security_rules:
  read: if request.auth != null && 
           (resource.data.owner_id == request.auth.uid || 
            resource.data.director_id == request.auth.uid ||
            isDirectorOfCompany(request.auth.uid, resource.data.managing_company_id))
  write: if request.auth != null && 
            (resource.data.owner_id == request.auth.uid || 
             resource.data.director_id == request.auth.uid)


// ====================
// CARS Collection
// ====================
collection: cars/{carId}
fields:
  // Владение (ОДИН гараж на автомобиль)
  - owner_id: String                 // USER_id владельца
  - garage_id: String                // ID гаража (personal_garage_XXX ИЛИ COMPANY_garage_XXX)
  - garage_type: String              // PERSONAL | COMPANY
  
  // ПРАВИЛО: Каждый автомобиль принадлежит ТОЛЬКО ОДНОМУ гаражу
  // garage_id определяет единственное место хранения/владения
  
  // Управление
  - company_id: String?              // COMPANY_id управляющей компании (опционально)
  
  // Основные данные
  - make: String                     // Марка
  - model: String                    // Модель
  - license_plate: String            // Гос. номер
  - status: String                   // AVAILABLE | IN_MAINTENANCE | SOLD
  - daily_rate: Number               // Дневная ставка
  - monthly_rate: Number             // Месячная ставка
  - photos_links: Array<String>      // Ссылки на фото
  - year: Number?                    // Год выпуска
  - color: String?                   // Цвет
  - vin: String?                     // VIN номер
  - created_at: Timestamp
  - updated_at: Timestamp

indexes:
  - owner_id (ascending)
  - garage_id (ascending)
  - garage_type (ascending)
  - company_id (ascending)
  - status (ascending)
  - license_plate (ascending)
  - compound: [garage_id, status]
  - compound: [owner_id, status]
  - compound: [company_id, status]

security_rules:
  read: if request.auth != null && 
           (resource.data.owner_id == request.auth.uid ||
            isDirectorOfCompany(request.auth.uid, resource.data.company_id) ||
            hasCarPermission(request.auth.uid, carId, 'view'))
  
  write: if request.auth != null && 
            (resource.data.owner_id == request.auth.uid ||
             (hasRole(request.auth.uid, 'DIRECTOR') && 
              isDirectorOfCompany(request.auth.uid, resource.data.company_id)))


// ====================
// CAR_PERMISSIONS Collection (Subcollection)
// ====================
collection: cars/{carId}/permissions/{userId}
fields:
  - user_id: String                  // ID пользователя с правами
  - car_id: String                   // ID автомобиля
  - can_view: Boolean                // Просмотр в календаре
  - can_edit: Boolean                // Редактирование деталей
  - can_book: Boolean                // Создание бронирований
  - can_confirm_booking: Boolean     // Подтверждение заявок
  - can_view_financials: Boolean     // Просмотр финансов
  - granted_at: Timestamp            // Когда выданы права
  - granted_by: String               // Кем выданы права

security_rules:
  read: if request.auth != null && 
           (request.auth.uid == userId ||
            isCarOwner(request.auth.uid, carId) ||
            isDirectorOfCar(request.auth.uid, carId))
  
  write: if request.auth != null && 
            (isCarOwner(request.auth.uid, carId) ||
             isDirectorOfCar(request.auth.uid, carId))


// ====================
// RENTALS Collection
// ====================
collection: rentals/{rentalId}
fields:
  // Основные связи
  - car_id: String                   // ID автомобиля
  - client_id: String                // ID клиента
  
  // Участники сделки
  - rental_user_id: String           // ID создателя брони (MANAGER/DIRECTOR)
  - car_owner_id: String             // ID владельца авто
  - managing_company_id: String?     // ID управляющей компании
  
  // Даты и статус
  - start_date: Timestamp            // Дата начала
  - end_date: Timestamp              // Дата окончания
  - status: String                   // PENDING | CONFIRMED | ACTIVE | COMPLETED | MAINTENANCE
  
  // Финансы
  - price_amount: Number             // Общая сумма для клиента
  - commission_amount: Number        // Комиссия менеджера/компании
  - deposit_amount: Number           // Залог
  - owner_earnings: Number           // Чистая прибыль владельца
  
  // Дополнительно
  - mileage_start: Number?           // Начальный пробег
  - mileage_end: Number?             // Конечный пробег
  - notes: String?                   // Заметки
  - created_at: Timestamp
  - updated_at: Timestamp
  
  // Чат
  - hasUnreadMessages: Boolean
  - lastMessageAt: Timestamp?
  - messageCount: Number

indexes:
  - car_id (ascending)
  - client_id (ascending)
  - rental_user_id (ascending)
  - car_owner_id (ascending)
  - managing_company_id (ascending)
  - status (ascending)
  - start_date (descending)
  - compound: [car_id, status]
  - compound: [car_id, start_date]
  - compound: [rental_user_id, status]
  - compound: [car_owner_id, status]

security_rules:
  read: if request.auth != null && 
           (resource.data.rental_user_id == request.auth.uid ||
            resource.data.car_owner_id == request.auth.uid ||
            isDirectorOfCompany(request.auth.uid, resource.data.managing_company_id))
  
  write: if request.auth != null && 
            (resource.data.rental_user_id == request.auth.uid ||
             hasCarPermission(request.auth.uid, resource.data.car_id, 'book'))


// ====================
// CLIENTS Collection
// ====================
collection: clients/{clientId}
fields:
  - id: String                       // Уникальный ID
  - name: String                     // ФИО клиента
  - phone: String                    // Телефон
  - email: String                    // Email
  - driver_license_info: String?     // Данные водительских прав (OCR)
  - passport_info: String?           // Данные паспорта (OCR)
  - created_at: Timestamp
  - updated_at: Timestamp

indexes:
  - phone (ascending)
  - email (ascending)
  - name (ascending)

security_rules:
  read: if request.auth != null
  write: if request.auth != null && 
            (hasRole(request.auth.uid, 'DIRECTOR') || 
             hasRole(request.auth.uid, 'MANAGER'))


// ====================
// MESSAGES Collection (Subcollection of Rentals)
// ====================
collection: rentals/{rentalId}/messages/{messageId}
fields:
  - id: String
  - rental_id: String                // ID аренды
  - sender_id: String                // ID отправителя
  - sender_name: String              // Имя отправителя
  - text: String                     // Текст сообщения
  - created_at: Timestamp
  - is_read: Boolean                 // Прочитано ли

indexes:
  - rental_id (ascending)
  - created_at (descending)
  - compound: [rental_id, created_at]

security_rules:
  read: if request.auth != null && 
           hasAccessToRental(request.auth.uid, rentalId)
  write: if request.auth != null && 
            hasAccessToRental(request.auth.uid, rentalId)


/**
 * ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ SECURITY RULES
 * ==========================================
 */

function hasRole(userId, role) {
  return get(/databases/$(database)/documents/users/$(userId)).data.global_role == role;
}

function isDirector(userId, orgId) {
  let org = get(/databases/$(database)/documents/organizations/$(orgId));
  return org.data.director_user_id == userId;
}

function hasAccessToOrg(userId, orgId) {
  let user = get(/databases/$(database)/documents/users/$(userId));
  return orgId in user.data.organizations;
}

function isDirectorOfCompany(userId, companyId) {
  let company = get(/databases/$(database)/documents/organizations/$(companyId));
  return company.data.director_user_id == userId;
}

function isCarOwner(userId, carId) {
  let car = get(/databases/$(database)/documents/cars/$(carId));
  return car.data.owner_id == userId;
}

function isDirectorOfCar(userId, carId) {
  let car = get(/databases/$(database)/documents/cars/$(carId));
  return car.data.company_id != null && 
         isDirectorOfCompany(userId, car.data.company_id);
}

function hasCarPermission(userId, carId, permission) {
  let perm = get(/databases/$(database)/documents/cars/$(carId)/permissions/$(userId));
  return perm != null && 
         (permission == 'view' && perm.data.can_view ||
          permission == 'edit' && perm.data.can_edit ||
          permission == 'book' && perm.data.can_book ||
          permission == 'confirm' && perm.data.can_confirm_booking ||
          permission == 'financials' && perm.data.can_view_financials);
}

function hasAccessToRental(userId, rentalId) {
  let rental = get(/databases/$(database)/documents/rentals/$(rentalId));
  return rental.data.rental_user_id == userId ||
         rental.data.car_owner_id == userId ||
         isDirectorOfCompany(userId, rental.data.managing_company_id);
}


/**
 * ПРИМЕРЫ ЗАПРОСОВ
 * ================
 */

// Получить все автомобили владельца
cars.where('owner_id', '==', userId)

// Получить все автомобили в гараже
cars.where('garage_id', '==', garageId)

// Получить все автомобили, управляемые компанией
cars.where('company_id', '==', companyId)

// Получить все доступные автомобили компании
cars.where('company_id', '==', companyId)
    .where('status', '==', 'AVAILABLE')

// Получить все аренды менеджера
rentals.where('rental_user_id', '==', managerId)
       .where('status', 'in', ['PENDING', 'CONFIRMED', 'ACTIVE'])

// Получить все аренды владельца автомобилей
rentals.where('car_owner_id', '==', ownerId)
       .orderBy('start_date', 'desc')

// Получить права пользователя на автомобиль
cars/{carId}/permissions/{userId}

// Получить все автомобили, к которым пользователь имеет доступ
cars.where('company_id', '==', userCompanyId)
// + отдельный запрос к подколлекции permissions
