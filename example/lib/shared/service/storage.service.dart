import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:query_signals/p_signals/models/storable.model.dart';
import 'package:query_signals/storage/base_persisted_storage.abstract.dart';
import 'package:sembast/sembast_io.dart';

class StorageService implements BasePersistedStorage {
  static const String dbName = 'persist_signals_db.db';
  static const int dbVersion = 1;
  late Database _db;

  @override
  Future<StorageService> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(appDir.path, dbName);
    _db = await databaseFactoryIo.openDatabase(dbPath, version: dbVersion);
    return this;
  }

  // Simple key-value operations for primitive signals
  @override
  Future<String?> get(String key) async {
    final store = StoreRef.main();
    return await store.record(key).get(_db) as String?;
  }

  @override
  Future<void> set(String key, String value) async {
    final store = StoreRef.main();
    await store.record(key).put(_db, value);
  }

  @override
  Future<void> delete(String key) async {
    final store = StoreRef.main();
    await store.record(key).delete(_db);
  }

  StoreRef<String, Map<String, dynamic>> _getStore(String storeName) {
    return stringMapStoreFactory.store(storeName);
  }

  @override
  Future<void> setRecord(
    String storeName,
    String id,
    Map<String, dynamic> data,
  ) async {
    final store = _getStore(storeName);
    await store.record(id).put(_db, data);
  }

  // Replace all records in a store with the provided list
  @override
  Future<void> setRecords(
    String storeName,
    List<Map<String, dynamic>> records,
  ) async {
    final store = _getStore(storeName);

    return _db.transaction((txn) async {
      // Clear all existing records in the store
      await store.delete(txn);

      // Add all new records
      await Future.wait(
        records.asMap().entries.map((entry) {
          final index = entry.key;
          final record = entry.value;
          // Use index as ID if no 'id' field exists
          final id = record['id']?.toString() ?? index.toString();
          return store.record(id).put(txn, record);
        }),
      );
    });
  }

  // Type-safe helper for Storable objects
  Future<void> setStorableRecords<T extends StorableWithId>(
    String storeName,
    List<T> items,
  ) async {
    final records = items.map((item) => item.toJson()).toList();
    await setRecords(storeName, records);
  }

  // Add or update multiple records using their existing IDs
  Future<void> addRecords<T extends StorableWithId>(
    String storeName,
    List<T> items,
  ) async {
    final store = _getStore(storeName);

    return _db.transaction((txn) async {
      await Future.wait(
        items.map((item) {
          return store.record(item.id).put(txn, item.toJson());
        }),
      );
    });
  }

  Future<T> addRecord<T extends StorableWithId>(
    String storeName,
    T item,
  ) async {
    final store = _getStore(storeName);

    return _db.transaction((txn) async {
      await store.record(item.id).add(txn, item.toJson());
      return item;
    });
  }

  Future<void> updateRecord(
    String storeName,
    String id,
    Map<String, dynamic> data,
  ) async {
    final store = _getStore(storeName);
    await store.record(id).update(_db, data);
  }

  @override
  Future<Map<String, dynamic>?> getRecord(String storeName, String id) async {
    final store = _getStore(storeName);
    return await store.record(id).get(_db);
  }

  @override
  Future<List<Map<String, dynamic>>> getRecords(String storeName) async {
    final store = _getStore(storeName);
    return (await store.find(_db)).map((e) => e.value).toList();
  }

  // Advanced query with filters and sorting
  Future<List<Map<String, dynamic>>> queryRecords(
    String storeName, {
    Filter? filter,
    List<SortOrder>? sortOrders,
  }) async {
    final store = _getStore(storeName);
    final finder = Finder(filter: filter, sortOrders: sortOrders);
    return (await store.find(_db, finder: finder)).map((e) => e.value).toList();
  }

  @override
  Future<void> deleteRecord(String storeName, String id) async {
    final store = _getStore(storeName);

    try {
      await store.record(id).delete(_db);
    } catch (e) {
      print('error deleting record: $e');
    }
  }

  @override
  Future<void> deleteRecords(String storeName, List<String> ids) async {
    final store = _getStore(storeName);

    try {
      await _db.transaction((txn) async {
        await Future.wait(ids.map((id) => store.record(id).delete(txn)));
      });
    } catch (e) {
      print('Failed to delete records: $e');
    }
  }

  @override
  Future<void> clearStore(String storeName) async {
    final store = _getStore(storeName);
    await store.delete(_db);
  }

  // Listen to store changes
  Stream<List<RecordSnapshot<String, Map<String, dynamic>>>> watchStore(
    String storeName,
  ) {
    final store = _getStore(storeName);
    return store.query().onSnapshots(_db);
  }

  /// Gets a primitive value from storage
  @override
  Future<T?> getValue<T>(String key) async {
    final store = StoreRef.main();
    final record = await store.record(key).get(_db) as T;
    return record;
  }

  /// Sets a primitive value in storage
  @override
  Future<void> setValue<T>(String key, T value) async {
    final store = StoreRef.main();
    await store.record(key).put(_db, value);
  }

  /// Deletes a primitive value from storage
  @override
  Future<void> deleteValue(String key) async {
    final store = StoreRef.main();
    await store.record(key).delete(_db);
  }

  @override
  Future<void> clear() async {
    final store = StoreRef.main();
    await store.delete(_db);
  }
}
