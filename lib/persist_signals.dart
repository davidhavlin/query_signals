import 'package:flutter/foundation.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';

/// Global instance manager for PersistSignals
class PersistSignals {
  static PersistSignals? _instance;
  static BasePersistedStorage? _storage;

  /// Get the global instance
  static PersistSignals get I {
    if (_instance == null) {
      throw StateError(
        'PersistSignals not initialized. Call PersistSignals.init() first.',
      );
    }
    return _instance!;
  }

  BasePersistedStorage get storage => _storage!;

  /// Initialize PersistSignals with a storage implementation
  static Future<void> init(BasePersistedStorage storage) async {
    if (_instance != null) {
      debugPrint('PersistSignals already initialized');
      return;
    }

    _storage = storage;
    await _storage!.init();
    _instance = PersistSignals._();
  }

  PersistSignals._();

  /// Reset PersistSignals (mainly for testing)
  @visibleForTesting
  static void reset() {
    _instance = null;
    _storage = null;
  }
}
