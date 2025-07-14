import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:query_signals/p_signals/client/p_signals_client.dart';
import 'package:query_signals/p_signals/models/storable.model.dart';
import 'package:query_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// A persisted list signal that handles individual item operations efficiently
///
/// **Features:**
/// - Individual record operations - only saves/updates/deletes specific items
/// - Optimistic updates for better UX
/// - Batch operations for performance
/// - Error recovery with rollback capabilities
/// - Advanced querying and filtering
///
/// **Requirements:** T must have an 'id' property and toJson()/fromJson() methods
///
/// **Usage:**
/// ```dart
/// final postsSignal = PComplexListSignal<Post>(
///   key: 'posts',
///   fromJson: Post.fromJson,
///   onError: (error, stackTrace) => print('Error: $error'),
/// );
///
/// // Add items
/// postsSignal.add(newPost);
/// postsSignal.addAll([post1, post2, post3]);
///
/// // Update items
/// await postsSignal.updateItem(postId, {'title': 'New Title'});
///
/// // Batch operations
/// await postsSignal.batchUpdate([
///   {'id': 'post1', 'title': 'Title 1'},
///   {'id': 'post2', 'title': 'Title 2'},
/// ]);
/// ```
class PComplexListSignal<T extends StorableWithId> extends ListSignal<T> {
  /// Unique key for storage
  final String key;

  /// Deserializer function for items
  final T Function(Map<String, dynamic>) fromJson;

  /// Storage instance
  final BasePersistedStorage store;

  /// Error handler for persistence operations
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Whether to enable optimistic updates
  final bool optimisticUpdates;

  /// Hydration state
  bool isHydrated = false;

  /// Loading state
  bool isLoading = false;

  /// Last error that occurred
  Object? lastError;

  final Completer<void> _hydrationCompleter = Completer<void>();

  PComplexListSignal({
    required this.key,
    required this.fromJson,
    List<T> initialValue = const [],
    this.onError,
    this.optimisticUpdates = true,
  })  : store = PSignalsClient.I.storage,
        super(List.from(initialValue)) {
    _loadData();
  }

  /// Wait for hydration to complete
  Future<void> waitForHydration() => _hydrationCompleter.future;

  /// Load data from storage with error handling
  Future<void> _loadData() async {
    if (isLoading) return;

    isLoading = true;

    try {
      final records = await store.getRecords(key);
      final items = records.map((record) => fromJson(record)).toList();
      super.value = items;
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    } finally {
      isLoading = false;
      isHydrated = true;
      if (!_hydrationCompleter.isCompleted) {
        _hydrationCompleter.complete();
      }
    }
  }

  /// Handle errors with optional custom handler
  Future<void> _handleError(Object error, StackTrace stackTrace) async {
    if (kDebugMode) {
      debugPrint('PComplexListSignal Error [$key]: $error');
    }

    onError?.call(error, stackTrace);
  }

  @override
  List<T> get value {
    if (!isHydrated && !isLoading) {
      _loadData().ignore();
    }
    return super.value;
  }

  @override
  set value(List<T> newValue) {
    super.value = newValue;
    _saveAllRecords(newValue).ignore();
  }

  /// Save all records to storage
  Future<void> _saveAllRecords(List<T> items) async {
    if (!isHydrated) return;

    try {
      final records = items
          .map((item) => {
                'id': item.id,
                ...(item as dynamic).toJson() as Map<String, dynamic>
              })
          .toList();
      await store.setRecords(key, records);
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    }
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

    _saveRecord(element).ignore();
  }

  @override
  void addAll(Iterable<T> iterable) {
    final itemsToSave = <T>[];

    for (final item in iterable) {
      final existingIndex = indexWhere((existing) => existing.id == item.id);
      if (existingIndex >= 0) {
        super[existingIndex] = item;
      } else {
        super.add(item);
      }
      itemsToSave.add(item);
    }

    _saveRecords(itemsToSave).ignore();
  }

  @override
  bool remove(Object? element) {
    if (element is T) {
      final removed = super.remove(element);
      if (removed) {
        _deleteRecord(element.id).ignore();
      }
      return removed;
    }
    return false;
  }

  @override
  T removeAt(int index) {
    final item = super.removeAt(index);
    _deleteRecord(item.id).ignore();
    return item;
  }

  @override
  void removeWhere(bool Function(T element) test) {
    final itemsToRemove = where(test).toList();
    super.removeWhere(test);

    final idsToDelete = itemsToRemove.map((item) => item.id).toList();
    _deleteRecords(idsToDelete).ignore();
  }

  @override
  void clear() {
    super.clear();
    _clearStore().ignore();
  }

  /// Save a single record to storage
  Future<void> _saveRecord(T item) async {
    if (!isHydrated) return;

    try {
      final data = (item as dynamic).toJson() as Map<String, dynamic>;
      await store.setRecord(key, item.id, data);
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    }
  }

  /// Save multiple records to storage
  Future<void> _saveRecords(List<T> items) async {
    if (!isHydrated) return;

    try {
      final records = items
          .map((item) => {
                'id': item.id,
                ...(item as dynamic).toJson() as Map<String, dynamic>
              })
          .toList();
      await store.setRecords(key, records);
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    }
  }

  /// Delete a single record from storage
  Future<void> _deleteRecord(String id) async {
    if (!isHydrated) return;

    try {
      await store.deleteRecord(key, id);
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    }
  }

  /// Delete multiple records from storage
  Future<void> _deleteRecords(List<String> ids) async {
    if (!isHydrated) return;

    try {
      await store.deleteRecords(key, ids);
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    }
  }

  /// Clear all records from storage
  Future<void> _clearStore() async {
    if (!isHydrated) return;

    try {
      await store.clearStore(key);
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    }
  }

  /// Update an existing item by ID with optimistic updates
  Future<T?> updateItem(String id, Map<String, dynamic> data) async {
    final index = indexWhere((item) => item.id == id);
    if (index >= 0) {
      final currentItem = this[index];
      final currentJson =
          (currentItem as dynamic).toJson() as Map<String, dynamic>;
      final updatedJson = {...currentJson, ...data};
      final updatedItem = fromJson(updatedJson);

      // Optimistic update
      if (optimisticUpdates) {
        super[index] = updatedItem;
      }

      try {
        await store.setRecord(key, id, updatedJson);
        if (!optimisticUpdates) {
          super[index] = updatedItem;
        }
        lastError = null;
        return updatedItem;
      } catch (error, stackTrace) {
        // Rollback on error
        if (optimisticUpdates) {
          super[index] = currentItem;
        }
        lastError = error;
        await _handleError(error, stackTrace);
        return null;
      }
    }

    // If item doesn't exist, create it
    final newItem = fromJson({'id': id, ...data});
    add(newItem);
    return newItem;
  }

  /// Batch update multiple items
  Future<List<T?>> batchUpdate(List<Map<String, dynamic>> updates) async {
    final results = <T?>[];
    final rollbackData = <int, T>{};

    try {
      // Prepare optimistic updates
      for (final update in updates) {
        final id = update['id'] as String;
        final index = indexWhere((item) => item.id == id);

        if (index >= 0) {
          final currentItem = this[index];
          final currentJson =
              (currentItem as dynamic).toJson() as Map<String, dynamic>;
          final updatedJson = {...currentJson, ...update};
          final updatedItem = fromJson(updatedJson);

          // Store rollback data
          rollbackData[index] = currentItem;

          // Optimistic update
          if (optimisticUpdates) {
            super[index] = updatedItem;
          }

          results.add(updatedItem);
        } else {
          // Create new item
          final newItem = fromJson(update);
          add(newItem);
          results.add(newItem);
        }
      }

      // Batch save to storage
      final recordsToSave = updates.map((update) => update).toList();
      await store.setRecords(key, recordsToSave);
      lastError = null;

      return results;
    } catch (error, stackTrace) {
      // Rollback optimistic updates
      if (optimisticUpdates) {
        for (final entry in rollbackData.entries) {
          super[entry.key] = entry.value;
        }
      }

      lastError = error;
      await _handleError(error, stackTrace);
      return results.map((e) => null).toList();
    }
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
    try {
      final record = await store.getRecord(key, id);
      return record != null ? fromJson(record) : null;
    } catch (error, stackTrace) {
      await _handleError(error, stackTrace);
      return null;
    }
  }

  /// Filter items by predicate
  List<T> filter(bool Function(T item) predicate) {
    return where(predicate).toList();
  }

  /// Find items by field value
  List<T> findByField(String fieldName, dynamic fieldValue) {
    return where((item) {
      final json = (item as dynamic).toJson() as Map<String, dynamic>;
      return json[fieldName] == fieldValue;
    }).toList();
  }

  /// Sort items by field
  void sortByField(String fieldName, {bool ascending = true}) {
    sort((a, b) {
      final aJson = (a as dynamic).toJson() as Map<String, dynamic>;
      final bJson = (b as dynamic).toJson() as Map<String, dynamic>;
      final aValue = aJson[fieldName];
      final bValue = bJson[fieldName];

      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return ascending ? -1 : 1;
      if (bValue == null) return ascending ? 1 : -1;

      final comparison = Comparable.compare(aValue, bValue);
      return ascending ? comparison : -comparison;
    });
  }

  /// Get unique values for a field
  List<dynamic> getUniqueValues(String fieldName) {
    final values = <dynamic>{};
    for (final item in this) {
      final json = (item as dynamic).toJson() as Map<String, dynamic>;
      final value = json[fieldName];
      if (value != null) {
        values.add(value);
      }
    }
    return values.toList();
  }

  /// Refresh the list from storage
  Future<void> refresh() async {
    await _loadData();
  }

  /// Get statistics about the list
  Map<String, dynamic> get stats => {
        'count': length,
        'isHydrated': isHydrated,
        'isLoading': isLoading,
        'hasError': lastError != null,
        'lastError': lastError?.toString(),
      };
}
