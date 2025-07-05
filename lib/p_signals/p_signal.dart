import 'dart:convert';

import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/mixins/p_signal.mixin.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

class PSignal<T> extends FlutterSignal<T> with PSignalMixin<T> {
  final T Function(Map<String, dynamic>)? fromJson;
  final Map<String, dynamic> Function(T)? valueToJson;

  PSignal({
    required T value,
    super.autoDispose,
    super.debugLabel,
    this.clearCache = false,
    required this.key,
    this.fromJson,
    this.valueToJson,
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

  @override
  T Function(String)? get customDecoder =>
      fromJson != null ? (json) => fromJson!(jsonDecode(json)) : null;

  @override
  String Function(T)? get customEncoder =>
      valueToJson != null ? (value) => jsonEncode(valueToJson!(value)) : null;
}
