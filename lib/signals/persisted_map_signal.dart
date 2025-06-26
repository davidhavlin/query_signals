import 'package:persist_signals/persist_signals.dart';
import 'package:persist_signals/signals/mixins/p_map_signal.mixin.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// A persisted map signal that can store any key-value pairs
class PersistedMapSignal<K, V> extends MapSignal<K, V>
    with PMapSignalMixin<K, V> {
  PersistedMapSignal({
    required this.key,
    required Map<K, V> value,
    this.clearCache = false,
  })  : store = PersistSignals.I.storage,
        super(value) {
    init().ignore();
  }

  @override
  final String key;

  @override
  final BasePersistedStorage store;

  @override
  final bool clearCache;
}

/// Example: For storing Company objects by ID
/// 
/// Usage:
/// ```dart
/// final companiesSignal = PersistedMapSignal<String, Map<String, dynamic>>(
///   key: 'companies',
///   value: {},
/// );
/// 
/// // Add a company
/// companiesSignal['company-1'] = company.toJson();
/// 
/// // Get a company
/// final companyJson = companiesSignal['company-1'];
/// final company = Company.fromJson(companyJson);
/// ```
