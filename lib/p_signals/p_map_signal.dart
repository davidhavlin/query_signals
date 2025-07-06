import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/mixins/p_map_signal.mixin.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// A persisted map signal that automatically saves key-value pairs to storage
///
/// **Best for:** Configuration settings, user preferences, cached data
/// **Features:**
/// - Automatic persistence on any map modification
/// - Type-safe key-value storage
/// - Efficient updates (saves entire map as one blob)
/// - Error recovery with fallback values
///
/// **Usage:**
/// ```dart
/// // String-dynamic map for settings
/// final settings = PMapSignal<String, dynamic>(
///   key: 'app_settings',
///   value: {
///     'theme': 'dark',
///     'notifications': true,
///     'language': 'en',
///   },
/// );
///
/// // Typed map for user preferences
/// final preferences = PMapSignal<String, bool>(
///   key: 'user_preferences',
///   value: {},
/// );
///
/// // Usage
/// settings['theme'] = 'light';
/// preferences['showTutorial'] = false;
/// ```
class PMapSignal<K, V> extends MapSignal<K, V> with PMapSignalMixin<K, V> {
  /// Error handler for persistence operations
  final void Function(Object error, StackTrace stackTrace)? onError;

  PMapSignal({
    required this.key,
    required Map<K, V> value,
    this.clearCache = false,
    this.onError,
  })  : store = PSignalsClient.I.storage,
        super(value) {
    init().ignore();
  }

  @override
  final String key;

  @override
  final BasePersistedStorage store;

  @override
  final bool clearCache;

  /// Get a value with a fallback
  V? getValue(K key, [V? defaultValue]) {
    return this[key] ?? defaultValue;
  }

  /// Set a value if the key doesn't exist
  V putIfAbsentValue(K key, V value) {
    return putIfAbsent(key, () => value);
  }

  /// Update a value if the key exists
  bool updateIfPresent(K key, V Function(V) updater) {
    if (containsKey(key)) {
      this[key] = updater(this[key] as V);
      return true;
    }
    return false;
  }

  /// Toggle a boolean value
  bool toggle(K key, [bool defaultValue = false]) {
    final current = this[key] as bool? ?? defaultValue;
    final newValue = !current;
    this[key] = newValue as V;
    return newValue;
  }

  /// Increment a numeric value
  num increment(K key, [num delta = 1, num defaultValue = 0]) {
    final current = this[key] as num? ?? defaultValue;
    final newValue = current + delta;
    this[key] = newValue as V;
    return newValue;
  }

  /// Merge another map into this one
  void merge(Map<K, V> other, {bool overwrite = true}) {
    for (final entry in other.entries) {
      if (overwrite || !containsKey(entry.key)) {
        this[entry.key] = entry.value;
      }
    }
  }

  /// Get all keys as a list
  List<K> get keysList => keys.toList();

  /// Get all values as a list
  List<V> get valuesList => values.toList();

  /// Get entries as a list
  List<MapEntry<K, V>> get entriesList => entries.toList();

  /// Filter entries by predicate
  Map<K, V> filter(bool Function(K key, V value) predicate) {
    final result = <K, V>{};
    for (final entry in entries) {
      if (predicate(entry.key, entry.value)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// Transform values while keeping keys
  Map<K, R> mapValues<R>(R Function(K key, V value) transform) {
    final result = <K, R>{};
    for (final entry in entries) {
      result[entry.key] = transform(entry.key, entry.value);
    }
    return result;
  }

  /// Get a copy of the map
  Map<K, V> get copy => Map.from(value);

  /// Get statistics about the map
  Map<String, dynamic> get stats => {
        'size': length,
        'isEmpty': isEmpty,
        'isNotEmpty': isNotEmpty,
        'keys': keysList,
      };
}
