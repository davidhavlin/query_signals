import 'dart:convert';

import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/mixins/p_signal.mixin.dart';
import 'package:persist_signals/p_signals/models/storable.model.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:signals/signals_flutter.dart';

/// A persisted signal that automatically saves/loads values to/from storage
///
/// **Features:**
/// - Automatic persistence on value changes
/// - Custom serialization support via fromJson/toJson
/// - Auto-serialization for HydratableModel types
/// - Error recovery with fallback values
/// - Hydration state management
/// - Optimistic updates
///
/// **Usage:**
/// ```dart
/// // Simple primitive signal
/// final counter = PSignal<int>(
///   key: 'counter',
///   value: 0,
/// );
///
/// // Complex object signal with HydratableModel
/// final user = PSignal<User>(
///   key: 'current_user',
///   value: User.empty(),
///   fromJson: User.fromJson,
/// );
///
/// // Complex object signal with custom serialization
/// final settings = PSignal<Settings>(
///   key: 'app_settings',
///   value: Settings.defaults,
///   fromJson: Settings.fromJson,
///   valueToJson: (s) => s.toJson(), // Only needed if not HydratableModel
/// );
/// ```
class PSignal<T> extends FlutterSignal<T> with PSignalMixin<T> {
  /// Custom deserializer for complex objects
  final T Function(Map<String, dynamic>)? fromJson;

  /// Custom serializer for complex objects (optional if T extends HydratableModel)
  final Map<String, dynamic> Function(T)? valueToJson;

  /// Fallback value used when storage fails to load
  final T? fallbackValue;

  /// Called when an error occurs during persistence operations
  final void Function(Object error, StackTrace stackTrace)? onError;

  PSignal({
    required T value,
    required this.key,
    super.autoDispose,
    super.debugLabel,
    this.clearCache = false,
    this.fromJson,
    this.valueToJson,
    this.fallbackValue,
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

  @override
  T Function(String)? get customDecoder =>
      fromJson != null ? (json) => fromJson!(jsonDecode(json)) : null;

  @override
  String Function(T)? get customEncoder {
    if (valueToJson != null) {
      return (value) => jsonEncode(valueToJson!(value));
    }

    // Auto-detect HydratableModel and use toJson()
    if (value is Storable) {
      return (value) => jsonEncode((value as Storable).toJson());
    }

    return null;
  }

  @override
  T get fallback => fallbackValue ?? super.value;

  @override
  void Function(Object, StackTrace)? get errorHandler => onError;

  /// Reset the signal to its initial value and clear from storage
  Future<void> reset() async {
    try {
      await store.delete(key);
      value = fallback;
    } catch (error, stackTrace) {
      _handleError(error, stackTrace);
    }
  }

  /// Manually refresh the signal from storage
  Future<void> refresh() async {
    try {
      await init();
    } catch (error, stackTrace) {
      _handleError(error, stackTrace);
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    onError?.call(error, stackTrace);
    // fallback to default behavior in mixin
  }
}
