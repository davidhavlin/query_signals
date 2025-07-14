import 'dart:convert';

import 'package:query_signals/p_signals/client/p_signals_client.dart';
import 'package:query_signals/p_signals/mixins/p_list_signal.mixin.dart';
import 'package:query_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// A persisted list signal that saves the ENTIRE list as one blob to storage
///
/// **Best for:** Small to medium lists (< 100 items), simple data structures
/// **Features:**
/// - Automatic persistence on any list modification
/// - Custom serialization support for complex objects
/// - Error recovery with fallback values
/// - Efficient for small lists that change frequently
///
/// **Usage:**
/// ```dart
/// // Primitive list
/// final tags = PListSignal<String>(
///   key: 'tags',
///   value: ['flutter', 'dart'],
/// );
///
/// // Complex object list
/// final todos = PListSignal<Todo>(
///   key: 'todos',
///   value: [],
///   fromJson: Todo.fromJson,
///   valueToJson: (todo) => todo.toJson(),
/// );
/// ```
///
/// **Note:** For large lists with individual item operations,
/// use [PComplexListSignal] instead for better performance.
class PListSignal<T> extends ListSignal<T> with PListSignalMixin<T> {
  /// Custom deserializer for complex objects
  final T Function(Map<String, dynamic>)? fromJson;

  /// Custom serializer for complex objects
  final Map<String, dynamic> Function(T)? valueToJson;

  PListSignal({
    required this.key,
    List<T> value = const [],
    this.clearCache = false,
    this.fromJson,
    this.valueToJson,
  })  : store = PSignalsClient.I.storage,
        super(List.from(value)) {
    init().ignore();
  }

  @override
  final String key;

  @override
  final BasePersistedStorage store;

  @override
  final bool clearCache;

  @override
  T Function(Map<String, dynamic>)? get customItemDecoder => fromJson;

  @override
  Map<String, dynamic> Function(T)? get customItemEncoder => valueToJson;

  /// Add multiple items efficiently
  void addAllUnique(Iterable<T> items) {
    for (final item in items) {
      if (!contains(item)) {
        add(item);
      }
    }
  }

  /// Remove items by predicate and return count
  int removeCount(bool Function(T) predicate) {
    final initialLength = length;
    removeWhere(predicate);
    return initialLength - length;
  }

  /// Replace all items with new items
  void replaceAll(List<T> newItems) {
    value = List.from(newItems);
  }

  /// Get a copy of the list
  List<T> get copy => List.from(value);
}

/// Backward compatibility alias
typedef PersistedPrimitiveListSignal<T> = PListSignal<T>;
