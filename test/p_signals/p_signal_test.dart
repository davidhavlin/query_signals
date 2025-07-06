import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/p_signal.dart';

import 'mock_storage.dart';
import 'test_models.dart';

/// Tracking mock storage for testing call counts
class _TrackingMockStorage extends MockStorage {
  int getCallCount = 0;
  int setCallCount = 0;

  @override
  Future<String?> get(String key) async {
    getCallCount++;
    return super.get(key);
  }

  @override
  Future<void> set(String key, String value) async {
    setCallCount++;
    return super.set(key, value);
  }
}

void main() {
  group('PSignal Tests', () {
    late MockStorage mockStorage;

    setUp(() {
      mockStorage = MockStorage();
      PSignalsClient.init(mockStorage);
    });

    tearDown(() {
      PSignalsClient.reset();
      mockStorage.reset();
    });

    group('Basic Persistence', () {
      test('should persist int values', () async {
        final signal = PSignal<int>(
          key: 'test_int',
          value: 42,
        );

        await signal.waitForHydration();
        expect(signal.value, 42);
        // Initial value is not saved to storage during hydration
        expect(mockStorage.hasKey('test_int'), isFalse);

        // Update value - this should be immediate
        signal.value = 100;
        expect(signal.value, 100); // Immediate update

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.hasKey('test_int'), isTrue);
        expect(mockStorage.getRawValue('test_int'), '100');
      });

      test('should persist string values', () async {
        final signal = PSignal<String>(
          key: 'test_string',
          value: 'hello',
        );

        await signal.waitForHydration();
        signal.value = 'world';
        expect(signal.value, 'world'); // Immediate update

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.getRawValue('test_string'), '"world"');
      });

      test('should persist boolean values', () async {
        final signal = PSignal<bool>(
          key: 'test_bool',
          value: false,
        );

        await signal.waitForHydration();
        signal.value = true;
        expect(signal.value, true); // Immediate update

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.getRawValue('test_bool'), 'true');
      });

      test('should persist null values', () async {
        final signal = PSignal<String?>(
          key: 'test_nullable',
          value: null,
        );

        await signal.waitForHydration();
        signal.value = 'not null';
        expect(signal.value, 'not null'); // Immediate update

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.getRawValue('test_nullable'), '"not null"');

        signal.value = null;
        expect(signal.value, null); // Immediate update

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.getRawValue('test_nullable'), 'null');
      });
    });

    group('Complex Object Persistence', () {
      test('should persist complex objects with custom serialization',
          () async {
        final signal = PSignal<TestSettings>(
          key: 'test_settings',
          value: TestSettings.defaults,
          fromJson: TestSettings.fromJson,
          valueToJson: (settings) => settings.toJson(),
        );

        await signal.waitForHydration();
        expect(signal.value, TestSettings.defaults);

        final newSettings = TestSettings.defaults.copyWith(
          theme: 'light',
          fontSize: 16.0,
        );
        signal.value = newSettings;

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, newSettings);
        expect(signal.value.theme, 'light');
        expect(signal.value.fontSize, 16.0);
      });

      test('should load persisted complex objects on initialization', () async {
        // First, manually put data in storage to simulate existing data
        await mockStorage.set(
            'settings_persistence',
            jsonEncode({
              'theme': 'custom',
              'fontSize': 14.0,
              'notificationsEnabled': true,
              'favoriteColors': ['red', 'blue']
            }));

        // Create signal with same key - should load persisted data during hydration
        final signal = PSignal<TestSettings>(
          key: 'settings_persistence',
          value: TestSettings.defaults, // Initial value
          fromJson: TestSettings.fromJson,
          valueToJson: (settings) => settings.toJson(),
        );

        await signal.waitForHydration();
        expect(signal.value.theme, 'custom'); // Should load from storage
        expect(signal.value.fontSize, 14.0);
        expect(signal.value.notificationsEnabled, true);
      });
    });

    group('Error Handling', () {
      test('should handle storage get errors with fallback', () async {
        mockStorage.simulateGetError();

        final signal = PSignal<String>(
          key: 'error_test',
          value: 'initial',
          fallbackValue: 'fallback',
        );

        await signal.waitForHydration();
        expect(signal.value, 'fallback');
        expect(signal.lastError, isNotNull);
        expect(signal.lastError.toString(), contains('Mock get error'));
      });

      test('should handle storage set errors gracefully', () async {
        final errorMessages = <String>[];
        final signal = PSignal<String>(
          key: 'set_error_test',
          value: 'initial',
          onError: (error, stackTrace) {
            errorMessages.add(error.toString());
          },
        );

        await signal.waitForHydration();
        mockStorage.simulateSetError();

        signal.value = 'updated';
        expect(signal.value, 'updated'); // Value still updates locally

        // Wait briefly for background save attempt
        await Future.delayed(Duration(milliseconds: 10));
        expect(errorMessages, isNotEmpty);
        expect(errorMessages.first, contains('Mock set error'));
        expect(signal.lastError, isNotNull);
      });

      test('should handle json decode errors with fallback', () async {
        // Manually set invalid JSON
        await mockStorage.set('invalid_json', 'invalid json data');

        final signal = PSignal<TestSettings>(
          key: 'invalid_json',
          value: TestSettings.defaults,
          fallbackValue: TestSettings.defaults.copyWith(theme: 'safe'),
          fromJson: TestSettings.fromJson,
          valueToJson: (settings) => settings.toJson(),
        );

        await signal.waitForHydration();
        expect(signal.value.theme, 'safe'); // Should use fallback
        expect(signal.lastError, isNotNull);
      });
    });

    group('Hydration Management', () {
      test('should provide hydration state', () async {
        final signal = PSignal<int>(
          key: 'hydration_test',
          value: 0,
        );

        expect(signal.isHydrated, isFalse);
        // The constructor calls init().ignore(), so loading should be true
        expect(signal.isLoading, isTrue);

        await signal.waitForHydration();
        expect(signal.isHydrated, isTrue);
        expect(signal.isLoading, isFalse);
      });

      test('should wait for hydration completion', () async {
        mockStorage.delay = Duration(milliseconds: 50);

        final signal = PSignal<int>(
          key: 'hydration_wait',
          value: 123,
        );

        final stopwatch = Stopwatch()..start();
        signal.value; // Trigger hydration
        await signal.waitForHydration();
        stopwatch.stop();

        expect(signal.isHydrated, isTrue);
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
      });

      test('should only hydrate once', () async {
        // Create a tracking mock storage
        final trackingStorage = _TrackingMockStorage();

        // Reset client with tracking storage
        PSignalsClient.reset();
        PSignalsClient.init(trackingStorage);

        final signal = PSignal<int>(
          key: 'once_hydration',
          value: 0,
        );

        // Multiple value accesses
        signal.value;
        signal.value;
        signal.value;

        await signal.waitForHydration();
        expect(
            trackingStorage.getCallCount, 1); // Should only call storage once
      });
    });

    group('Cache Management', () {
      test('should clear cache when clearCache is true', () async {
        // First, save some data
        await mockStorage.set('cache_test', '"persisted_value"');

        final signal = PSignal<String>(
          key: 'cache_test',
          value: 'initial',
          clearCache: true,
        );

        await signal.waitForHydration();
        expect(signal.value, 'initial'); // Should use initial, not persisted
        expect(mockStorage.hasKey('cache_test'), isFalse); // Should be cleared
      });

      test('should load from cache when clearCache is false', () async {
        // First, save some data
        await mockStorage.set('cache_load_test', '"persisted_value"');

        final signal = PSignal<String>(
          key: 'cache_load_test',
          value: 'initial',
          clearCache: false,
        );

        await signal.waitForHydration();
        expect(signal.value, 'persisted_value'); // Should load persisted value
      });
    });

    group('Manual Operations', () {
      test('should manually refresh from storage', () async {
        final signal = PSignal<String>(
          key: 'refresh_test',
          value: 'initial',
        );

        await signal.waitForHydration();
        expect(signal.value, 'initial');

        // Manually update storage
        await mockStorage.set('refresh_test', '"external_update"');

        // Refresh should load the external update
        await signal.refresh();
        expect(signal.value, 'external_update');
      });

      test('should reset to fallback value', () async {
        final signal = PSignal<String>(
          key: 'reset_test',
          value: 'initial',
          fallbackValue: 'reset_value',
        );

        await signal.waitForHydration();
        signal.value = 'updated';

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, 'updated');
        expect(mockStorage.hasKey('reset_test'), isTrue);

        await signal.reset();
        expect(signal.value, 'reset_value');
        expect(mockStorage.hasKey('reset_test'), isFalse);
      });

      test('should clear storage manually', () async {
        final signal = PSignal<String>(
          key: 'clear_test',
          value: 'initial',
        );

        await signal.waitForHydration();
        signal.value = 'updated';

        // Wait briefly for background save
        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.hasKey('clear_test'), isTrue);

        await signal.clearStorage();
        expect(mockStorage.hasKey('clear_test'), isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty storage gracefully', () async {
        final signal = PSignal<String>(
          key: 'empty_storage',
          value: 'default',
        );

        await signal.waitForHydration();
        expect(signal.value, 'default');
        expect(signal.lastError, isNull);
      });

      test('should handle concurrent modifications', () async {
        final signal = PSignal<int>(
          key: 'concurrent_test',
          value: 0,
        );

        await signal.waitForHydration();

        // Simulate rapid updates
        signal.value = 1;
        signal.value = 2;
        signal.value = 3;
        signal.value = 4;
        signal.value = 5;

        expect(signal.value, 5); // Should have the final value
      });

      test('should handle very large objects', () async {
        final largeData = List.generate(1000, (i) => 'item_$i');
        final signal = PSignal<List<String>>(
          key: 'large_data',
          value: largeData,
        );

        await signal.waitForHydration();
        expect(signal.value.length, 1000);
        expect(signal.value.first, 'item_0');
        expect(signal.value.last, 'item_999');
      });
    });

    group('Hydration (Real-world scenario)', () {
      test('should hydrate from previously persisted data', () async {
        // Create first signal and set a value
        final signal1 = PSignal<String>(
          key: 'test-123',
          value: 'initial',
        );

        await signal1.waitForHydration();
        signal1.value = 'persisted_value';

        // Create second signal with same key but different initial value
        final signal2 = PSignal<String>(
          key: 'test-123',
          value: 'different_initial', // This should be overridden by hydration
        );

        await signal2.waitForHydration();

        // signal2 should have loaded the persisted value from signal1
        expect(signal2.value, 'persisted_value');
        expect(signal2.value, isNot('different_initial'));
      });

      test('should hydrate complex objects using HydratableModel', () async {
        // Create first signal with a user
        final signal1 = PSignal<TestUser>(
          key: 'user-456',
          value: TestUser.sample,
          fromJson: TestUser.fromJson,
        );

        await signal1.waitForHydration();
        final customUser = TestUser.sample.copyWith(name: 'Updated Name');
        signal1.value = customUser;

        // Create second signal with same key but different initial value
        final signal2 = PSignal<TestUser>(
          key: 'user-456',
          value: TestUser.sampleInactive, // Different initial value
          fromJson: TestUser.fromJson,
        );

        await signal2.waitForHydration();

        // Should have loaded the persisted user from signal1
        expect(signal2.value.name, 'Updated Name');
        expect(signal2.value.id, TestUser.sample.id);
        expect(signal2.value, isNot(TestUser.sampleInactive));
      });

      test('should use fallback when no persisted data exists', () async {
        final signal = PSignal<String>(
          key: 'non-existent-key',
          value: 'fallback_value',
        );

        await signal.waitForHydration();

        // Should use the initial value since nothing was persisted
        expect(signal.value, 'fallback_value');
      });
    });

    group('HydratableModel Auto-serialization', () {
      test('should auto-serialize HydratableModel without valueToJson',
          () async {
        final signal = PSignal<TestSettings>(
          key: 'auto_serialize_test',
          value: TestSettings.defaults,
          fromJson: TestSettings.fromJson,
          // No valueToJson needed - should auto-detect HydratableModel
        );

        await signal.waitForHydration();

        final customSettings = TestSettings.defaults.copyWith(
          theme: 'custom_theme',
          fontSize: 18.0,
        );
        signal.value = customSettings;

        // Create another signal to test if it was properly serialized
        final signal2 = PSignal<TestSettings>(
          key: 'auto_serialize_test',
          value: TestSettings.defaults,
          fromJson: TestSettings.fromJson,
        );

        await signal2.waitForHydration();

        expect(signal2.value.theme, 'custom_theme');
        expect(signal2.value.fontSize, 18.0);
      });
    });
  });
}
