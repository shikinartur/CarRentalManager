import 'package:cloud_firestore/cloud_firestore.dart';

/// Базовый сервис для работы с Firestore коллекциями
/// Содержит общие методы для CRUD операций
abstract class FirestoreService<T> {
  /// Получить ссылку на коллекцию
  CollectionReference get collection;

  /// Создать объект из Firestore документа
  T fromFirestore(DocumentSnapshot doc);

  /// Преобразовать объект в Map для сохранения в Firestore
  Map<String, dynamic> toFirestore(T item);

  /// Создать новый документ
  Future<String> create(T item) async {
    try {
      final docRef = await collection.add(toFirestore(item));
      return docRef.id;
    } catch (e) {
      throw Exception('Ошибка создания документа: $e');
    }
  }

  /// Создать документ с указанным ID
  Future<void> createWithId(String id, T item) async {
    try {
      await collection.doc(id).set(toFirestore(item));
    } catch (e) {
      throw Exception('Ошибка создания документа с ID: $e');
    }
  }

  /// Получить документ по ID
  Future<T?> getById(String id) async {
    try {
      final doc = await collection.doc(id).get();
      if (doc.exists) {
        return fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка получения документа: $e');
    }
  }

  /// Получить все документы
  Future<List<T>> getAll() async {
    try {
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения документов: $e');
    }
  }

  /// Получить документы с фильтром
  Future<List<T>> getWhere(String field, dynamic value) async {
    try {
      final snapshot = await collection.where(field, isEqualTo: value).get();
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения отфильтрованных документов: $e');
    }
  }

  /// Получить документы с пагинацией
  Future<List<T>> getPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = collection.limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Ошибка получения документов с пагинацией: $e');
    }
  }

  /// Обновить документ
  Future<void> update(String id, T item) async {
    try {
      await collection.doc(id).update(toFirestore(item));
    } catch (e) {
      throw Exception('Ошибка обновления документа: $e');
    }
  }

  /// Обновить отдельные поля документа
  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    try {
      fields['updated_at'] = Timestamp.now();
      await collection.doc(id).update(fields);
    } catch (e) {
      throw Exception('Ошибка обновления полей документа: $e');
    }
  }

  /// Удалить документ
  Future<void> delete(String id) async {
    try {
      await collection.doc(id).delete();
    } catch (e) {
      throw Exception('Ошибка удаления документа: $e');
    }
  }

  /// Подписаться на изменения коллекции
  Stream<List<T>> streamAll() {
    return collection.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => fromFirestore(doc)).toList(),
    );
  }

  /// Подписаться на изменения документа
  Stream<T?> streamById(String id) {
    return collection.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        return fromFirestore(doc);
      }
      return null;
    });
  }

  /// Подписаться на изменения отфильтрованных документов
  Stream<List<T>> streamWhere(String field, dynamic value) {
    return collection.where(field, isEqualTo: value).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => fromFirestore(doc)).toList(),
    );
  }

  /// Проверить существование документа
  Future<bool> exists(String id) async {
    try {
      final doc = await collection.doc(id).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Получить количество документов в коллекции
  Future<int> count() async {
    try {
      final snapshot = await collection.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Ошибка подсчета документов: $e');
    }
  }
}