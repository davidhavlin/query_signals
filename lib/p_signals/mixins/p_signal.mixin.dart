import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// Base class that contains all common persistence logic
abstract class PersistableSignalBase<T> {
  String get key;
  BasePersistedStorage get store;
  bool get clearCache;
  T get fallback;
  void Function(Object error, StackTrace stackTrace)? get errorHandler;

  bool isHydrated = false;
  bool isLoading = false;
  Object? lastError;
  final Completer<void> _hydrationCompleter = Completer<void>();

  /// Wait for the signal to be hydrated from storage
  Future<void> waitForHydration() => _hydrationCompleter.future;

  /// Initialize the signal by loading from storage or clearing cache
  Future<void> init() async {
    if (isLoading) return;

    isLoading = true;

    try {
      if (clearCache) {
        await _clearCache();
      } else {
        await _loadFromStorage();
      }
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

  /// Clear the cache and remove from storage
  Future<void> _clearCache() async {
    await clearStorage();
    setValue(fallback);
  }

  /// Load value from storage with fallback handling
  Future<void> _loadFromStorage() async {
    try {
      final storedValue = await store.get(key);
      if (storedValue != null) {
        final decodedValue = decode(storedValue);
        setValue(decodedValue);
      } else {
        // No stored value, use current value as default
        setValue(getCurrentValue());
      }
    } catch (error) {
      // If decoding fails, use fallback value
      setValue(fallback);
      rethrow;
    }
  }

  /// Save value to storage with error handling
  Future<void> save(T value) async {
    if (!isHydrated) return; // Don't save until hydrated

    try {
      final encodedValue = encode(value);
      await store.set(key, encodedValue);
      lastError = null;
    } catch (error, stackTrace) {
      lastError = error;
      await _handleError(error, stackTrace);
    }
  }

  /// Clear the stored value
  Future<void> clearStorage() async {
    await store.delete(key);
  }

  /// Handle errors with optional custom handler
  Future<void> _handleError(Object error, StackTrace stackTrace) async {
    if (kDebugMode) {
      debugPrint('PSignal Error [$key]: $error');
    }

    errorHandler?.call(error, stackTrace);

    // Additional error recovery strategies could be added here
    // For now, we just log and continue
  }

  // Abstract methods that each specific implementation must provide
  T getCurrentValue();
  void setValue(T value);
  T decode(String value);
  String encode(T value);
}

/// Mixin that adds persistence capabilities to Signal<T>
mixin PSignalMixin<T> on Signal<T> {
  String get key;
  BasePersistedStorage get store;
  bool get clearCache;
  T get fallback;
  void Function(Object error, StackTrace stackTrace)? get errorHandler;

  /// Custom decoder for complex types
  T Function(String)? get customDecoder => null;

  /// Custom encoder for complex types
  String Function(T)? get customEncoder => null;

  late final PersistableSignalBase<T> _persistable =
      _PersistableSignalImpl<T>(this);

  /// Get the current value, triggering hydration if needed
  @override
  T get value {
    if (!_persistable.isHydrated && !_persistable.isLoading) {
      _persistable.init().ignore();
    }
    return super.value;
  }

  /// Set the value and persist it
  @override
  set value(T value) {
    super.value = value;
    _persistable.save(value).ignore();
  }

  /// Whether the signal has been hydrated from storage
  bool get isHydrated => _persistable.isHydrated;

  /// Whether the signal is currently loading from storage
  bool get isLoading => _persistable.isLoading;

  /// The last error that occurred during persistence operations
  Object? get lastError => _persistable.lastError;

  /// Wait for the signal to be hydrated from storage
  Future<void> waitForHydration() => _persistable.waitForHydration();

  /// Initialize the signal (useful for manual initialization)
  Future<void> init() => _persistable.init();

  /// Clear the signal from storage
  Future<void> clearStorage() => _persistable.clearStorage();
}

/// Private implementation of the persistable signal base for regular signals
class _PersistableSignalImpl<T> extends PersistableSignalBase<T> {
  final Signal<T> _signal;
  final String _key;
  final BasePersistedStorage _store;
  final bool _shouldClearCache;

  _PersistableSignalImpl(this._signal)
      : _key = (_signal as dynamic).key,
        _store = (_signal as dynamic).store,
        _shouldClearCache = (_signal as dynamic).clearCache;

  @override
  String get key => _key;

  @override
  BasePersistedStorage get store => _store;

  @override
  bool get clearCache => _shouldClearCache;

  @override
  T get fallback => (_signal as dynamic).fallback ?? _signal.value;

  @override
  void Function(Object, StackTrace)? get errorHandler =>
      (_signal as dynamic).errorHandler;

  @override
  T getCurrentValue() => _signal.value;

  @override
  void setValue(T value) => _signal.value = value;

  @override
  T decode(String value) {
    final customDecoder = (_signal as dynamic).customDecoder;
    if (customDecoder != null) return customDecoder(value);
    return jsonDecode(value);
  }

  @override
  String encode(T value) {
    final customEncoder = (_signal as dynamic).customEncoder;
    if (customEncoder != null) return customEncoder(value);
    return jsonEncode(value);
  }
}
