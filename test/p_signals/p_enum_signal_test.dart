import 'package:flutter_test/flutter_test.dart';
import 'package:query_signals/p_signals/client/p_signals_client.dart';
import 'package:query_signals/p_signals/p_enum_signal.dart';

import 'mock_storage.dart';
import 'test_models.dart';

void main() {
  group('PEnumSignal Tests', () {
    late MockStorage mockStorage;

    setUp(() {
      mockStorage = MockStorage();
      PSignalsClient.init(mockStorage);
    });

    tearDown(() {
      PSignalsClient.reset();
      mockStorage.reset();
    });

    group('Basic Enum Persistence', () {
      test('should persist enum values', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'test_theme',
          value: TestTheme.light,
          values: TestTheme.values,
        );

        await signal.waitForHydration();
        expect(signal.value, TestTheme.light);
        // Initial value is not saved to storage during hydration
        expect(mockStorage.hasKey('test_theme'), isFalse);

        // Update value
        signal.value = TestTheme.dark;
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, TestTheme.dark);
        expect(mockStorage.getRawValue('test_theme'), 'dark');
        expect(mockStorage.hasKey('test_theme'), isTrue);
      });

      test('should persist all enum values', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'all_themes',
          value: TestTheme.light,
          values: TestTheme.values,
        );

        await signal.waitForHydration();

        // Test all enum values
        for (final theme in TestTheme.values) {
          signal.value = theme;
          expect(signal.value, theme); // Immediate update

          await Future.delayed(Duration(milliseconds: 10));
          expect(mockStorage.getRawValue('all_themes'), theme.name);
        }
      });

      test('should load persisted enum values on initialization', () async {
        // First, manually put data in storage to simulate existing data
        await mockStorage.set('theme_persistence', 'system');

        // Create signal with same key - should load persisted data during hydration
        final signal = PEnumSignal<TestTheme>(
          key: 'theme_persistence',
          value: TestTheme.light, // Initial value
          values: TestTheme.values,
        );

        await signal.waitForHydration();
        expect(signal.value, TestTheme.system); // Should load from storage
      });
    });

    group('Nullable Enum Handling', () {
      test('should handle null enum values', () async {
        final signal = PEnumSignal<TestTheme?>(
          key: 'nullable_theme',
          value: null,
          values: [...TestTheme.values, null], // Include null in values
        );

        await signal.waitForHydration();
        expect(signal.value, null);
        // Initial value not saved during hydration
        expect(mockStorage.hasKey('nullable_theme'), isFalse);

        // Set to actual enum value
        signal.value = TestTheme.dark;
        expect(signal.value, TestTheme.dark); // Immediate update

        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.getRawValue('nullable_theme'), 'dark');

        // Set back to null
        signal.value = null;
        expect(signal.value, null); // Immediate update

        await Future.delayed(Duration(milliseconds: 10));
        expect(mockStorage.getRawValue('nullable_theme'), 'null');
      });

      test('should provide null-safe utility methods', () async {
        final signal = PEnumSignal<TestTheme?>(
          key: 'nullable_utils',
          value: null,
          values: [...TestTheme.values, null],
        );

        await signal.waitForHydration();
        expect(signal.value, null);
        expect(signal.isNull, isTrue);

        signal.value = TestTheme.light;
        expect(signal.isNull, isFalse);
        expect(signal.requireValue, TestTheme.light);
        expect(signal.valueOr(TestTheme.dark), TestTheme.light);
      });

      test('should handle valueOr correctly', () async {
        final signal = PEnumSignal<TestTheme?>(
          key: 'value_or_test',
          value: null,
          values: [...TestTheme.values, null],
        );

        await signal.waitForHydration();
        expect(signal.value, null);
        expect(signal.valueOr(TestTheme.dark), TestTheme.dark);

        signal.value = TestTheme.light;
        expect(signal.valueOr(TestTheme.dark), TestTheme.light);
      });
    });

    group('Error Handling', () {
      test('should handle storage get errors with fallback', () async {
        mockStorage.simulateGetError();

        final signal = PEnumSignal<TestTheme>(
          key: 'error_test',
          value: TestTheme.light,
          values: TestTheme.values,
          fallbackValue: TestTheme.system,
        );

        await signal.waitForHydration();
        expect(signal.value, TestTheme.system);
        expect(signal.lastError, isNotNull);
      });

      test('should handle invalid enum values with fallback', () async {
        // Manually set invalid enum value
        await mockStorage.set('invalid_enum', 'invalid_value');

        final signal = PEnumSignal<TestTheme>(
          key: 'invalid_enum',
          value: TestTheme.light,
          values: TestTheme.values,
          fallbackValue: TestTheme.dark,
        );

        await signal.waitForHydration();
        expect(signal.value, TestTheme.dark); // Should use fallback
        // The error should be captured in lastError
        expect(signal.lastError, isNotNull);
      });

      test('should handle storage set errors gracefully', () async {
        final errorMessages = <String>[];
        final signal = PEnumSignal<TestTheme>(
          key: 'set_error_test',
          value: TestTheme.light,
          values: TestTheme.values,
          onError: (error, stackTrace) {
            errorMessages.add(error.toString());
          },
        );

        await signal.waitForHydration();
        mockStorage.simulateSetError();

        signal.value = TestTheme.dark;
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, TestTheme.dark); // Value still updates locally
        expect(errorMessages, isNotEmpty);
        expect(signal.lastError, isNotNull);
      });
    });

    group('Utility Methods', () {
      test('should provide allValues getter', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'all_values_test',
          value: TestTheme.light,
          values: TestTheme.values,
        );

        await signal.waitForHydration();
        expect(signal.allValues, TestTheme.values);
        expect(signal.allValues.length, 4);
      });

      test('should provide requireValue for non-null access', () async {
        final signal = PEnumSignal<TestTheme?>(
          key: 'require_value_test',
          value: TestTheme.light,
          values: [...TestTheme.values, null],
        );

        await signal.waitForHydration();
        expect(signal.requireValue, TestTheme.light);

        signal.value = null;
        await Future.delayed(Duration(milliseconds: 10));
        expect(() => signal.requireValue, throwsStateError);
      });
    });

    group('Hydration Management', () {
      test('should provide hydration state', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'hydration_test',
          value: TestTheme.light,
          values: TestTheme.values,
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

        final signal = PEnumSignal<TestTheme>(
          key: 'hydration_wait',
          value: TestTheme.light,
          values: TestTheme.values,
        );

        final stopwatch = Stopwatch()..start();
        signal.value; // Trigger hydration
        await signal.waitForHydration();
        stopwatch.stop();

        expect(signal.isHydrated, isTrue);
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
      });
    });

    group('Manual Operations', () {
      test('should manually refresh from storage', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'refresh_test',
          value: TestTheme.light,
          values: TestTheme.values,
        );

        await signal.waitForHydration();
        expect(signal.value, TestTheme.light);

        // Manually update storage
        await mockStorage.set('refresh_test', 'dark');

        // Refresh should load the external update
        await signal.refresh();
        expect(signal.value, TestTheme.dark);
      });

      test('should reset to fallback value', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'reset_test',
          value: TestTheme.light,
          values: TestTheme.values,
          fallbackValue: TestTheme.system,
        );

        await signal.waitForHydration();
        signal.value = TestTheme.dark;
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, TestTheme.dark);
        expect(mockStorage.hasKey('reset_test'), isTrue);

        await signal.reset();
        expect(signal.value, TestTheme.system);
        expect(mockStorage.hasKey('reset_test'), isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty enum values list', () async {
        expect(
            () => PEnumSignal<TestTheme>(
                  key: 'empty_values',
                  value: TestTheme.light,
                  values: [], // Empty list
                ),
            throwsAssertionError);
      });

      test('should handle single enum value', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'single_value',
          value: TestTheme.light,
          values: [TestTheme.light], // Single value
        );

        await signal.waitForHydration();
        expect(signal.value, TestTheme.light);
        expect(signal.allValues.length, 1);
        expect(signal.allValues.first, TestTheme.light);
      });

      test('should handle concurrent modifications', () async {
        final signal = PEnumSignal<TestTheme>(
          key: 'concurrent_enum',
          value: TestTheme.light,
          values: TestTheme.values,
        );

        await signal.waitForHydration();

        // Simulate rapid updates
        signal.value = TestTheme.dark;
        signal.value = TestTheme.system;
        signal.value = TestTheme.custom;
        signal.value = TestTheme.light;

        await Future.delayed(Duration(milliseconds: 20));
        expect(signal.value, TestTheme.light); // Should have the final value
      });
    });
  });
}
