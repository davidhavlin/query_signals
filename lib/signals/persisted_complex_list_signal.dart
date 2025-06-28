import 'dart:async';

import 'package:persist_signals/persist_signals.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:persist_signals/storage/storable.types.dart';
import 'package:signals/signals_flutter.dart';

/// A persisted list signal that handles individual item operations efficiently
/// Uses individual record operations - adds/updates/removes only specific items in storage
/// Perfect for large lists where you don't want to save everything on each change
///
/// Requirements: T must have an 'id' property and toJson()/fromJson() methods
class PersistedComplexListSignal<T extends HasId> extends ListSignal<T> {
  final String key;
  final T Function(Map<String, dynamic>) fromJson;
  final BasePersistedStorage store;

  bool isHydrated = false;
  final Completer<void> _hydrationCompleter = Completer<void>();

  PersistedComplexListSignal({
    required this.key,
    required this.fromJson,
    List<T> initialValue = const [],
  })  : store = PersistSignals.I.storage,
        super(List.from(initialValue)) {
    _loadData();
  }

  Future<void> waitForHydration() => _hydrationCompleter.future;

  Future<void> _loadData() async {
    try {
      // Load all records from the store
      final records = await store.getRecords(key);
      final items = records.map((record) => fromJson(record)).toList();
      super.value = items;
    } catch (e) {
      // debugPrint('Error loading persisted complex list: $e');
    } finally {
      isHydrated = true;
      _hydrationCompleter.complete();
    }
  }

  @override
  List<T> get value {
    if (!isHydrated) _loadData().ignore();
    return super.value;
  }

  @override
  set value(List<T> newValue) {
    super.value = newValue;
    // Replace all records in storage
    final records = newValue
        .map((item) => {
              'id': item.id,
              ...(item as dynamic).toJson() as Map<String, dynamic>
            })
        .toList();
    store.setRecords(key, records).ignore();
  }

  @override
  void add(T element) {
    final existingIndex = indexWhere((item) => item.id == element.id);
    if (existingIndex >= 0) {
      // Update existing item
      super[existingIndex] = element;
    } else {
      // Add new item
      super.add(element);
    }

    // Save only this item to storage
    final data = (element as dynamic).toJson() as Map<String, dynamic>;
    store.setRecord(key, element.id, data).ignore();
  }

  @override
  void addAll(Iterable<T> iterable) {
    final recordsToSave = <Map<String, dynamic>>[];

    for (final item in iterable) {
      final existingIndex = indexWhere((existing) => existing.id == item.id);
      if (existingIndex >= 0) {
        super[existingIndex] = item;
      } else {
        super.add(item);
      }

      recordsToSave.add({
        'id': item.id,
        ...(item as dynamic).toJson() as Map<String, dynamic>
      });
    }

    // Save all items at once
    store.setRecords(key, recordsToSave).ignore();
  }

  @override
  bool remove(Object? element) {
    if (element is T) {
      final removed = super.remove(element);
      if (removed) {
        // Remove only this item from storage
        store.deleteRecord(key, element.id).ignore();
      }
      return removed;
    }
    return false;
  }

  @override
  T removeAt(int index) {
    final item = super.removeAt(index);
    // Remove only this item from storage
    store.deleteRecord(key, item.id).ignore();
    return item;
  }

  @override
  void removeWhere(bool Function(T element) test) {
    final itemsToRemove = where(test).toList();
    super.removeWhere(test);

    // Remove only the deleted items from storage
    final idsToDelete = itemsToRemove.map((item) => item.id).toList();
    store.deleteRecords(key, idsToDelete).ignore();
  }

  @override
  void clear() {
    super.clear();
    // Clear the entire store
    store.clearStore(key).ignore();
  }

  /// Update an existing item by ID
  Future<T?> updateItem(String id, Map<String, dynamic> data) async {
    final index = indexWhere((item) => item.id == id);
    if (index >= 0) {
      final currentItem = this[index];
      final currentJson =
          (currentItem as dynamic).toJson() as Map<String, dynamic>;
      final updatedJson = {...currentJson, ...data};
      final updatedItem = fromJson(updatedJson);

      super[index] = updatedItem;
      // Update only this item in storage
      await store.setRecord(key, id, updatedJson);
      return updatedItem;
    }

    // If item doesn't exist, create it
    final newItem = fromJson({'id': id, ...data});
    add(newItem);
    return newItem;
  }

  /// Remove item by ID
  bool removeById(String id) {
    final index = indexWhere((item) => item.id == id);
    if (index >= 0) {
      removeAt(index);
      return true;
    }
    return false;
  }

  /// Find item by ID
  T? findById(String id) {
    try {
      return firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get item directly from storage by ID (doesn't affect the list)
  Future<T?> getItemFromStorage(String id) async {
    final record = await store.getRecord(key, id);
    return record != null ? fromJson(record) : null;
  }
}
