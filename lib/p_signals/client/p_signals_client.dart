import 'package:flutter/foundation.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';

/// Global instance manager for PSignalsClient
class PSignalsClient {
  static PSignalsClient? _instance;
  static BasePersistedStorage? _storage;

  /// Get the global instance
  static PSignalsClient get I {
    if (_instance == null) {
      throw StateError(
        'PSignalsClient not initialized. Call PSignalsClient.init() first.',
      );
    }
    return _instance!;
  }

  BasePersistedStorage get storage => _storage!;

  /// Initialize PSignalsClient with a storage implementation
  static void init(BasePersistedStorage storage) {
    if (_instance != null) {
      debugPrint('PSignalsClient already initialized');
      return;
    }

    _storage = storage;
    _instance = PSignalsClient._();
  }

  PSignalsClient._();

  /// Reset PSignalsClient (mainly for testing)
  @visibleForTesting
  static void reset() {
    _instance = null;
    _storage = null;
  }
}
