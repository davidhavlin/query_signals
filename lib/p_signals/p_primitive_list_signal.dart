import 'dart:convert';

import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/mixins/p_list_signal.mixin.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// A persisted list signal that saves the ENTIRE list as one blob to storage
/// Works with ANY type: primitives [1, 2, 3], objects [Company(...), Company(...)], etc.
/// For more efficient individual item operations, use PersistedComplexListSignal
class PListSignal<T> extends ListSignal<T> with PListSignalMixin<T> {
  final T Function(Map<String, dynamic>)? fromJson;
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
}

// For backward compatibility, keep the old name as an alias
typedef PersistedPrimitiveListSignal<T> = PListSignal<T>;
