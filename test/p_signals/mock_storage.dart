import 'dart:async';
import 'dart:convert';

import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';

/// Mock storage implementation for testing
class MockStorage extends BasePersistedStorage {
  final Map<String, String> _data = {};
  final Map<String, Map<String, Map<String, dynamic>>> _records = {};

  bool shouldFailOnNextOperation = false;
  bool shouldFailOnInit = false;
  bool shouldFailOnGet = false;
  bool shouldFailOnSet = false;
  String? failureMessage;

  // Simulation delays
  Duration delay = Duration.zero;

  void reset() {
    _data.clear();
    _records.clear();
    shouldFailOnNextOperation = false;
    shouldFailOnInit = false;
    shouldFailOnGet = false;
    shouldFailOnSet = false;
    failureMessage = null;
    delay = Duration.zero;
  }

  void simulateError({String? message}) {
    shouldFailOnNextOperation = true;
    failureMessage = message ?? 'Mock storage error';
  }

  void simulateGetError() {
    shouldFailOnGet = true;
    failureMessage = 'Mock get error';
  }

  void simulateSetError() {
    shouldFailOnSet = true;
    failureMessage = 'Mock set error';
  }

  Future<void> _checkAndThrow() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    if (shouldFailOnNextOperation) {
      shouldFailOnNextOperation = false;
      throw Exception(failureMessage ?? 'Mock storage error');
    }
  }

  @override
  Future<void> init() async {
    await _checkAndThrow();
    if (shouldFailOnInit) {
      throw Exception(failureMessage ?? 'Mock init error');
    }
  }

  @override
  Future<String?> get(String key) async {
    await _checkAndThrow();
    if (shouldFailOnGet) {
      shouldFailOnGet = false;
      throw Exception(failureMessage ?? 'Mock get error');
    }
    return _data[key];
  }

  @override
  Future<void> set(String key, String value) async {
    await _checkAndThrow();
    if (shouldFailOnSet) {
      shouldFailOnSet = false;
      throw Exception(failureMessage ?? 'Mock set error');
    }
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    await _checkAndThrow();
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    await _checkAndThrow();
    _data.clear();
    _records.clear();
  }

  @override
  Future<void> setRecord(
      String storeName, String id, Map<String, dynamic> data) async {
    await _checkAndThrow();
    if (shouldFailOnSet) {
      shouldFailOnSet = false;
      throw Exception(failureMessage ?? 'Mock setRecord error');
    }

    _records[storeName] ??= {};
    _records[storeName]![id] = Map.from(data);
  }

  @override
  Future<Map<String, dynamic>?> getRecord(String storeName, String id) async {
    await _checkAndThrow();
    if (shouldFailOnGet) {
      shouldFailOnGet = false;
      throw Exception(failureMessage ?? 'Mock getRecord error');
    }

    return _records[storeName]?[id];
  }

  @override
  Future<void> deleteRecord(String storeName, String id) async {
    await _checkAndThrow();
    _records[storeName]?.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getRecords(String storeName) async {
    await _checkAndThrow();
    if (shouldFailOnGet) {
      shouldFailOnGet = false;
      throw Exception(failureMessage ?? 'Mock getRecords error');
    }

    final store = _records[storeName];
    if (store == null) return [];
    return store.values.toList();
  }

  @override
  Future<void> setRecords(
      String storeName, List<Map<String, dynamic>> records) async {
    await _checkAndThrow();
    if (shouldFailOnSet) {
      shouldFailOnSet = false;
      throw Exception(failureMessage ?? 'Mock setRecords error');
    }

    _records[storeName] = {};
    for (final record in records) {
      final id = record['id'] as String;
      _records[storeName]![id] = Map.from(record);
    }
  }

  @override
  Future<void> deleteRecords(String storeName, List<String> ids) async {
    await _checkAndThrow();
    final store = _records[storeName];
    if (store != null) {
      for (final id in ids) {
        store.remove(id);
      }
    }
  }

  @override
  Future<void> clearStore(String storeName) async {
    await _checkAndThrow();
    _records.remove(storeName);
  }

  // Helper methods for testing
  bool hasKey(String key) => _data.containsKey(key);

  String? getRawValue(String key) => _data[key];

  Map<String, String> getAllData() => Map.from(_data);

  Map<String, Map<String, Map<String, dynamic>>> getAllRecords() =>
      Map.from(_records);

  int get dataCount => _data.length;

  int getRecordCount(String storeName) => _records[storeName]?.length ?? 0;
}
