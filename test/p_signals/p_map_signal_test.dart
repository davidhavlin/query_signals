import 'package:flutter_test/flutter_test.dart';
import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/p_map_signal.dart';

import 'mock_storage.dart';

void main() {
  group('PMapSignal Tests', () {
    late MockStorage mockStorage;

    setUp(() {
      mockStorage = MockStorage();
      PSignalsClient.init(mockStorage);
    });

    tearDown(() {
      PSignalsClient.reset();
      mockStorage.reset();
    });

    group('Basic Map Operations', () {
      test('should create and modify string map', () async {
        final signal = PMapSignal<String, String>(
          key: 'test_string_map',
          value: {'key1': 'value1', 'key2': 'value2'},
        );

        // Allow time for initialization
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, {'key1': 'value1', 'key2': 'value2'});

        // Update map
        signal.value = {'key3': 'value3', 'key4': 'value4'};
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'key3': 'value3', 'key4': 'value4'});
        expect(signal.value.length, 2);
      });

      test('should create and modify int map', () async {
        final signal = PMapSignal<String, int>(
          key: 'test_int_map',
          value: {'count1': 10, 'count2': 20},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, {'count1': 10, 'count2': 20});

        signal.value = {'count3': 30, 'count4': 40, 'count5': 50};
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'count3': 30, 'count4': 40, 'count5': 50});
        expect(signal.value.length, 3);
      });

      test('should handle empty map', () async {
        final signal = PMapSignal<String, String>(
          key: 'empty_map',
          value: {},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, {});
        expect(signal.value.isEmpty, isTrue);

        signal.value = {'key': 'value'};
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'key': 'value'});
        expect(signal.value.length, 1);
      });
    });

    group('Map Access Methods', () {
      test('should set and get individual keys', () async {
        final signal = PMapSignal<String, String>(
          key: 'access_test',
          value: {'initial': 'value'},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, {'initial': 'value'});

        signal['new_key'] = 'new_value';
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'initial': 'value', 'new_key': 'new_value'});
        expect(signal['new_key'], 'new_value');
        expect(signal['initial'], 'value');
      });

      test('should handle null values', () async {
        final signal = PMapSignal<String, String?>(
          key: 'nullable_map',
          value: {'key1': 'value1', 'key2': null},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, {'key1': 'value1', 'key2': null});
        expect(signal['key2'], null);

        signal['key3'] = null;
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'key1': 'value1', 'key2': null, 'key3': null});
        expect(signal['key3'], null);
      });
    });

    group('Map Modification Methods', () {
      test('should add and remove entries', () async {
        final signal = PMapSignal<String, int>(
          key: 'modify_test',
          value: {'a': 1, 'b': 2},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 2);

        // Add entry
        signal['c'] = 3;
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'a': 1, 'b': 2, 'c': 3});
        expect(signal.value.length, 3);

        // Remove entry
        signal.remove('b');
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'a': 1, 'c': 3});
        expect(signal.value.length, 2);
      });

      test('should clear map', () async {
        final signal = PMapSignal<String, String>(
          key: 'clear_test',
          value: {'item1': 'value1', 'item2': 'value2', 'item3': 'value3'},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 3);

        signal.clear();
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {});
        expect(signal.value.isEmpty, isTrue);
      });

      test('should add multiple entries', () async {
        final signal = PMapSignal<String, int>(
          key: 'add_all_test',
          value: {'a': 1, 'b': 2},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, {'a': 1, 'b': 2});

        signal.addAll({'c': 3, 'd': 4, 'e': 5});
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5});
        expect(signal.value.length, 5);
      });

      test('should update existing entries', () async {
        final signal = PMapSignal<String, String>(
          key: 'update_test',
          value: {'key1': 'old_value', 'key2': 'value2'},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal['key1'], 'old_value');

        signal['key1'] = 'new_value';
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal['key1'], 'new_value');
        expect(signal.value, {'key1': 'new_value', 'key2': 'value2'});
      });
    });

    group('Map Query Methods', () {
      test('should check if map contains key', () async {
        final signal = PMapSignal<String, String>(
          key: 'contains_test',
          value: {'apple': 'fruit', 'carrot': 'vegetable'},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.containsKey('apple'), isTrue);
        expect(signal.containsKey('banana'), isFalse);
      });

      test('should check if map contains value', () async {
        final signal = PMapSignal<String, String>(
          key: 'contains_value_test',
          value: {'apple': 'fruit', 'carrot': 'vegetable'},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.containsValue('fruit'), isTrue);
        expect(signal.containsValue('meat'), isFalse);
      });

      test('should get keys and values', () async {
        final signal = PMapSignal<String, String>(
          key: 'keys_values_test',
          value: {'apple': 'fruit', 'carrot': 'vegetable'},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.keys.toSet(), {'apple', 'carrot'});
        expect(signal.values.toSet(), {'fruit', 'vegetable'});
      });

      test('should handle empty map properties', () async {
        final signal = PMapSignal<String, String>(
          key: 'empty_props_test',
          value: {},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.isEmpty, isTrue);
        expect(signal.isNotEmpty, isFalse);
        expect(signal.length, 0);
        expect(signal.keys.isEmpty, isTrue);
        expect(signal.values.isEmpty, isTrue);
      });

      test('should handle non-empty map properties', () async {
        final signal = PMapSignal<String, String>(
          key: 'non_empty_props_test',
          value: {'item1': 'value1', 'item2': 'value2'},
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.isEmpty, isFalse);
        expect(signal.isNotEmpty, isTrue);
        expect(signal.length, 2);
        expect(signal.keys.length, 2);
        expect(signal.values.length, 2);
      });
    });

    group('Custom Utility Methods', () {
      test('should provide putIfAbsent functionality', () async {
        final signal = PMapSignal<String, String>(
          key: 'put_if_absent_test',
          value: {'existing': 'value'},
        );

        await Future.delayed(Duration(milliseconds: 10));

        // Should not overwrite existing key
        final result1 = signal.putIfAbsent('existing', () => 'new_value');
        expect(result1, 'value');
        expect(signal['existing'], 'value');

        // Should add new key
        final result2 = signal.putIfAbsent('new_key', () => 'new_value');
        expect(result2, 'new_value');
        expect(signal['new_key'], 'new_value');

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, {'existing': 'value', 'new_key': 'new_value'});
      });

      test('should provide update functionality', () async {
        final signal = PMapSignal<String, int>(
          key: 'update_test',
          value: {'count': 5},
        );

        await Future.delayed(Duration(milliseconds: 10));

        // Update existing key
        signal.update('count', (value) => value + 10);
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal['count'], 15);

        // Update with ifAbsent for missing key
        signal.update('new_count', (value) => value + 1, ifAbsent: () => 100);
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal['new_count'], 100);
      });

      test('should provide updateAll functionality', () async {
        final signal = PMapSignal<String, int>(
          key: 'update_all_test',
          value: {'a': 1, 'b': 2, 'c': 3},
        );

        await Future.delayed(Duration(milliseconds: 10));

        signal.updateAll((key, value) => value * 10);
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'a': 10, 'b': 20, 'c': 30});
      });

      test('should provide removeWhere functionality', () async {
        final signal = PMapSignal<String, int>(
          key: 'remove_where_test',
          value: {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5},
        );

        await Future.delayed(Duration(milliseconds: 10));

        // Remove entries where value is even
        signal.removeWhere((key, value) => value % 2 == 0);
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, {'a': 1, 'c': 3, 'e': 5});
      });

      test('should provide forEach functionality', () async {
        final signal = PMapSignal<String, int>(
          key: 'for_each_test',
          value: {'a': 1, 'b': 2, 'c': 3},
        );

        await Future.delayed(Duration(milliseconds: 10));

        final results = <String>[];
        signal.forEach((key, value) {
          results.add('$key:$value');
        });

        expect(results.toSet(), {'a:1', 'b:2', 'c:3'});
      });
    });

    group('Complex Data Types', () {
      test('should support complex key-value types', () async {
        final signal = PMapSignal<String, Map<String, dynamic>>(
          key: 'complex_map',
          value: {
            'user1': {'name': 'John', 'age': 30},
            'user2': {'name': 'Jane', 'age': 25},
          },
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 2);
        expect(signal['user1']?['name'], 'John');

        signal['user3'] = {'name': 'Bob', 'age': 35};
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value.length, 3);
        expect(signal['user3']?['name'], 'Bob');
      });

      test('should support list values', () async {
        final signal = PMapSignal<String, List<String>>(
          key: 'list_values',
          value: {
            'fruits': ['apple', 'banana'],
            'vegetables': ['carrot', 'lettuce'],
          },
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal['fruits']?.length, 2);
        expect(signal['fruits']?[0], 'apple');

        signal['grains'] = ['rice', 'wheat', 'oats'];
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value.length, 3);
        expect(signal['grains']?.length, 3);
      });
    });

    group('Edge Cases', () {
      test('should handle very large maps', () async {
        final largeMap = Map.fromEntries(
          List.generate(1000, (i) => MapEntry('key_$i', 'value_$i')),
        );

        final signal = PMapSignal<String, String>(
          key: 'large_map',
          value: largeMap,
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 1000);
        expect(signal['key_0'], 'value_0');
        expect(signal['key_999'], 'value_999');
      });

      test('should handle concurrent modifications', () async {
        final signal = PMapSignal<String, String>(
          key: 'concurrent_test',
          value: {'initial': 'value'},
        );

        await Future.delayed(Duration(milliseconds: 10));

        // Simulate rapid updates
        signal['key1'] = 'value1';
        signal['key2'] = 'value2';
        signal['key3'] = 'value3';
        signal.remove('initial');

        await Future.delayed(Duration(milliseconds: 20));
        expect(signal.value,
            {'key1': 'value1', 'key2': 'value2', 'key3': 'value3'});
      });

      test('should handle special characters in keys and values', () async {
        final signal = PMapSignal<String, String>(
          key: 'special_chars',
          value: {
            'key with spaces': 'value with spaces',
            'key-with-dashes': 'value-with-dashes',
            'key_with_underscores': 'value_with_underscores',
            'émojis🚀': '🎉🎊✨',
          },
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal['key with spaces'], 'value with spaces');
        expect(signal['émojis🚀'], '🎉🎊✨');

        signal['new🔑'] = 'new💎';
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal['new🔑'], 'new💎');
      });
    });
  });
}
