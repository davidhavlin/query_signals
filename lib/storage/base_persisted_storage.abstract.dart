/// Interface for implementing custom storage solutions
abstract class BasePersistedStorage {
  /// Initialize the storage
  Future<void> init();

  /// Get a value by key (for simple signals)
  Future<String?> get(String key);

  /// Set a value by key (for simple signals)
  Future<void> set(String key, String value);

  /// Delete a value by key (for simple signals)
  Future<void> delete(String key);

  /// Clear all values
  Future<void> clear();

  // === Individual Record Operations (for complex lists) ===

  /// Add or update a single record in a store
  Future<void> setRecord(
      String storeName, String id, Map<String, dynamic> data);

  /// Get a single record from a store
  Future<Map<String, dynamic>?> getRecord(String storeName, String id);

  /// Delete a single record from a store
  Future<void> deleteRecord(String storeName, String id);

  /// Get all records from a store
  Future<List<Map<String, dynamic>>> getRecords(String storeName);

  /// Add or update multiple records in a store
  Future<void> setRecords(String storeName, List<Map<String, dynamic>> records);

  /// Delete multiple records from a store
  Future<void> deleteRecords(String storeName, List<String> ids);

  /// Clear all records from a store
  Future<void> clearStore(String storeName);
}

// class AdvancedPersistedStorage extends BasePersistedStorage {}
