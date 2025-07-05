import 'dart:async';
import 'dart:convert';

import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// Base class that contains all common persistence logic
abstract class PersistableSignalBase<T> {
  String get key;
  BasePersistedStorage get store;
  bool get clearCache;

  bool isHydrated = false;
  final Completer<void> _hydrationCompleter = Completer<void>();

  Future<void> waitForHydration() => _hydrationCompleter.future;

  Future<void> init() async {
    if (clearCache) {
      _clearCache();
      return;
    }

    try {
      final val = await _load();
      setValue(val);
    } catch (e) {
      // debugPrint('Error loading persisted signal: $e');
    } finally {
      isHydrated = true;
      _hydrationCompleter.complete();
    }
  }

  void _clearCache() {
    clearStorage().ignore();
    isHydrated = true;
    _hydrationCompleter.complete();
  }

  Future<T> _load() async {
    final val = await store.get(key);
    if (val == null) return getCurrentValue();
    return decode(val);
  }

  Future<void> save(T value) async {
    final str = encode(value);
    await store.set(key, str);
  }

  Future<void> clearStorage() async {
    await store.delete(key);
  }

  // Abstract methods that each specific implementation must provide
  T getCurrentValue();
  void setValue(T value);
  T decode(String value);
  String encode(T value);
}

mixin PSignalMixin<T> on Signal<T> {
  String get key;
  BasePersistedStorage get store;
  bool get clearCache;

  T Function(String)? get customDecoder => null;
  String Function(T)? get customEncoder => null;

  late final PersistableSignalBase<T> _persistable =
      _PersistableSignalImpl<T>(this);

  @override
  T get value {
    if (!_persistable.isHydrated) _persistable.init().ignore();
    return super.value;
  }

  @override
  set value(T value) {
    super.value = value;
    _persistable.save(value).ignore();
  }

  Future<void> waitForHydration() => _persistable.waitForHydration();

  Future<void> init() => _persistable.init();
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
