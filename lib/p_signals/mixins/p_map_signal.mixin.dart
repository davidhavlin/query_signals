import 'dart:async';
import 'dart:convert';

import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';
import 'p_signal.mixin.dart';

mixin PMapSignalMixin<K, V> on MapSignal<K, V> {
  String get key;
  BasePersistedStorage get store;
  bool get clearCache;

  late final PersistableSignalBase<Map<K, V>> _persistable =
      _PersistableMapSignalImpl<K, V>(this);

  @override
  Map<K, V> get value {
    if (!_persistable.isHydrated && !_persistable.isLoading) {
      _persistable.init().ignore();
    }
    return super.value;
  }

  @override
  set value(Map<K, V> value) {
    super.value = value;
    _persistable.save(value).ignore();
  }

  Future<void> waitForHydration() => _persistable.waitForHydration();

  Future<void> init() => _persistable.init();

  @override
  void addAll(Map<K, V> other) {
    super.addAll(other);
    _persistable.save(value).ignore();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> entries) {
    super.addEntries(entries);
    _persistable.save(value).ignore();
  }

  @override
  void clear() {
    super.clear();
    _persistable.save(value).ignore();
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final result = super.putIfAbsent(key, ifAbsent);
    _persistable.save(value).ignore();
    return result;
  }

  @override
  V? remove(Object? key) {
    final result = super.remove(key);
    _persistable.save(value).ignore();
    return result;
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    super.removeWhere(test);
    _persistable.save(value).ignore();
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final result = super.update(key, update, ifAbsent: ifAbsent);
    _persistable.save(value).ignore();
    return result;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    super.updateAll(update);
    _persistable.save(value).ignore();
  }

  @override
  void operator []=(K key, V value) {
    super[key] = value;
    _persistable.save(this.value).ignore();
  }
}

/// Private implementation for MapSignal persistence
class _PersistableMapSignalImpl<K, V> extends PersistableSignalBase<Map<K, V>> {
  final MapSignal<K, V> _signal;
  final String _key;
  final BasePersistedStorage _store;
  final bool _shouldClearCache;

  _PersistableMapSignalImpl(this._signal)
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
  Map<K, V> get fallback => (_signal as dynamic).fallback ?? _signal.value;

  @override
  void Function(Object, StackTrace)? get errorHandler =>
      (_signal as dynamic).errorHandler;

  @override
  Map<K, V> getCurrentValue() => _signal.value;

  @override
  void setValue(Map<K, V> value) => _signal.value = value;

  @override
  Map<K, V> decode(String value) {
    final Map<dynamic, dynamic> decoded = jsonDecode(value);
    return decoded.map((key, value) => MapEntry(key as K, value as V));
  }

  @override
  String encode(Map<K, V> value) => jsonEncode(value);
}
