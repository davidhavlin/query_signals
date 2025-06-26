import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';
import 'p_signal.mixin.dart';

mixin PListSignalMixin<T> on ListSignal<T> {
  String get key;
  BasePersistedStorage get store;
  bool get clearCache;

  T Function(Map<String, dynamic>)? get customItemDecoder => null;
  Map<String, dynamic> Function(T)? get customItemEncoder => null;

  late final PersistableSignalBase<List<T>> _persistable =
      _PersistableListSignalImpl<T>(this);

  @override
  List<T> get value {
    if (!_persistable.isHydrated) _persistable.init().ignore();
    return super.value;
  }

  @override
  set value(List<T> value) {
    super.value = value;
    _persistable.save(value).ignore();
  }

  Future<void> waitForHydration() => _persistable.waitForHydration();

  Future<void> init() => _persistable.init();

  @override
  void add(T element) {
    super.add(element);
    _persistable.save(value).ignore();
  }

  @override
  void addAll(Iterable<T> elements) {
    super.addAll(elements);
    _persistable.save(value).ignore();
  }

  @override
  void clear() {
    super.clear();
    _persistable.save(value).ignore();
  }

  @override
  void insert(int index, T element) {
    super.insert(index, element);
    _persistable.save(value).ignore();
  }

  @override
  void insertAll(int index, Iterable<T> elements) {
    super.insertAll(index, elements);
    _persistable.save(value).ignore();
  }

  @override
  bool remove(Object? element) {
    final result = super.remove(element);
    _persistable.save(value).ignore();
    return result;
  }

  @override
  T removeAt(int index) {
    final result = super.removeAt(index);
    _persistable.save(value).ignore();
    return result;
  }

  @override
  void removeRange(int start, int end) {
    super.removeRange(start, end);
    _persistable.save(value).ignore();
  }

  @override
  void removeWhere(bool Function(T element) test) {
    super.removeWhere(test);
    _persistable.save(value).ignore();
  }

  @override
  void replaceRange(int start, int end, Iterable<T> replacements) {
    super.replaceRange(start, end, replacements);
    _persistable.save(value).ignore();
  }

  @override
  void retainWhere(bool Function(T element) test) {
    super.retainWhere(test);
    _persistable.save(value).ignore();
  }

  @override
  void setAll(int index, Iterable<T> elements) {
    super.setAll(index, elements);
    _persistable.save(value).ignore();
  }

  @override
  void setRange(int start, int end, Iterable<T> elements, [int skipCount = 0]) {
    super.setRange(start, end, elements, skipCount);
    _persistable.save(value).ignore();
  }

  @override
  void shuffle([Random? random]) {
    super.shuffle(random);
    _persistable.save(value).ignore();
  }

  @override
  void sort([int Function(T a, T b)? compare]) {
    super.sort(compare);
    _persistable.save(value).ignore();
  }
}

/// Private implementation for ListSignal persistence
class _PersistableListSignalImpl<T> extends PersistableSignalBase<List<T>> {
  final ListSignal<T> _signal;
  final String _key;
  final BasePersistedStorage _store;
  final bool _shouldClearCache;

  _PersistableListSignalImpl(this._signal)
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
  List<T> getCurrentValue() => _signal.value;

  @override
  void setValue(List<T> value) => _signal.value = value;

  @override
  List<T> decode(String value) {
    final List<dynamic> decoded = jsonDecode(value);
    final customDecoder = (_signal as dynamic).customItemDecoder;

    if (customDecoder != null) {
      return decoded
          .map((item) => customDecoder(item as Map<String, dynamic>))
          .toList()
          .cast<T>();
    }

    return decoded.cast<T>();
  }

  @override
  String encode(List<T> value) {
    final customEncoder = (_signal as dynamic).customItemEncoder;

    if (customEncoder != null) {
      final encoded = value.map((item) => customEncoder(item)).toList();
      return jsonEncode(encoded);
    }

    return jsonEncode(value);
  }
}
