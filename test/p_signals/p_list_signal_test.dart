import 'package:flutter_test/flutter_test.dart';
import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/p_primitive_list_signal.dart';

import 'mock_storage.dart';

void main() {
  group('PListSignal Tests', () {
    late MockStorage mockStorage;

    setUp(() {
      mockStorage = MockStorage();
      PSignalsClient.init(mockStorage);
    });

    tearDown(() {
      PSignalsClient.reset();
      mockStorage.reset();
    });

    group('Basic List Operations', () {
      test('should create and modify string list', () async {
        final signal = PListSignal<String>(
          key: 'test_strings',
          value: ['hello', 'world'],
        );

        // Allow time for initialization
        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, ['hello', 'world']);

        // Update list
        signal.value = ['foo', 'bar', 'baz'];
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['foo', 'bar', 'baz']);
        expect(signal.value.length, 3);
      });

      test('should create and modify int list', () async {
        final signal = PListSignal<int>(
          key: 'test_ints',
          value: [1, 2, 3],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, [1, 2, 3]);

        signal.value = [10, 20, 30, 40];
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, [10, 20, 30, 40]);
        expect(signal.value.length, 4);
      });

      test('should handle empty list', () async {
        final signal = PListSignal<String>(
          key: 'empty_list',
          value: [],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, []);
        expect(signal.value.isEmpty, isTrue);

        signal.value = ['item'];
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['item']);
        expect(signal.value.length, 1);
      });
    });

    group('List Modification Methods', () {
      test('should add items to list', () async {
        final signal = PListSignal<String>(
          key: 'add_test',
          value: ['initial'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, ['initial']);

        signal.add('new_item');
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['initial', 'new_item']);
        expect(signal.value.length, 2);
      });

      test('should remove items from list', () async {
        final signal = PListSignal<String>(
          key: 'remove_test',
          value: ['item1', 'item2', 'item3'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 3);

        signal.remove('item2');
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['item1', 'item3']);
        expect(signal.value.length, 2);
      });

      test('should clear list', () async {
        final signal = PListSignal<String>(
          key: 'clear_test',
          value: ['item1', 'item2', 'item3'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 3);

        signal.clear();
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, []);
        expect(signal.value.isEmpty, isTrue);
      });

      test('should add multiple items', () async {
        final signal = PListSignal<int>(
          key: 'add_all_test',
          value: [1, 2],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, [1, 2]);

        signal.addAll([3, 4, 5]);
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, [1, 2, 3, 4, 5]);
        expect(signal.value.length, 5);
      });

      test('should remove item at index', () async {
        final signal = PListSignal<String>(
          key: 'remove_at_test',
          value: ['a', 'b', 'c', 'd'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 4);

        signal.removeAt(1);
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['a', 'c', 'd']);
        expect(signal.value.length, 3);
      });

      test('should insert item at index', () async {
        final signal = PListSignal<String>(
          key: 'insert_test',
          value: ['a', 'c', 'd'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, ['a', 'c', 'd']);

        signal.insert(1, 'b');
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['a', 'b', 'c', 'd']);
        expect(signal.value.length, 4);
      });
    });

    group('List Query Methods', () {
      test('should check if list contains item', () async {
        final signal = PListSignal<String>(
          key: 'contains_test',
          value: ['apple', 'banana', 'orange'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.contains('banana'), isTrue);
        expect(signal.contains('grape'), isFalse);
      });

      test('should find index of item', () async {
        final signal = PListSignal<String>(
          key: 'index_test',
          value: ['apple', 'banana', 'orange'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.indexOf('banana'), 1);
        expect(signal.indexOf('grape'), -1);
      });

      test('should get first and last items', () async {
        final signal = PListSignal<String>(
          key: 'first_last_test',
          value: ['first', 'middle', 'last'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.first, 'first');
        expect(signal.last, 'last');
      });

      test('should handle empty list properties', () async {
        final signal = PListSignal<String>(
          key: 'empty_props_test',
          value: [],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.isEmpty, isTrue);
        expect(signal.isNotEmpty, isFalse);
        expect(signal.length, 0);
      });

      test('should handle non-empty list properties', () async {
        final signal = PListSignal<String>(
          key: 'non_empty_props_test',
          value: ['item1', 'item2'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.isEmpty, isFalse);
        expect(signal.isNotEmpty, isTrue);
        expect(signal.length, 2);
      });
    });

    group('Custom Methods', () {
      test('should provide addAllUnique method', () async {
        final signal = PListSignal<String>(
          key: 'unique_test',
          value: ['item1', 'item2'],
        );

        await Future.delayed(Duration(milliseconds: 10));

        // Add unique items
        signal.addAllUnique(['item2', 'item3', 'item4']);
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['item1', 'item2', 'item3', 'item4']);
        expect(signal.value.length, 4);
      });

      test('should provide removeCount method', () async {
        final signal = PListSignal<String>(
          key: 'remove_count_test',
          value: ['apple', 'banana', 'apple', 'orange', 'apple'],
        );

        await Future.delayed(Duration(milliseconds: 10));

        final removedCount = signal.removeCount((item) => item == 'apple');
        await Future.delayed(Duration(milliseconds: 10));

        expect(removedCount, 3);
        expect(signal.value, ['banana', 'orange']);
      });

      test('should provide replaceAll method', () async {
        final signal = PListSignal<String>(
          key: 'replace_all_test',
          value: ['old1', 'old2', 'old3'],
        );

        await Future.delayed(Duration(milliseconds: 10));

        signal.replaceAll(['new1', 'new2']);
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['new1', 'new2']);
        expect(signal.value.length, 2);
      });

      test('should provide copy method', () async {
        final signal = PListSignal<String>(
          key: 'copy_test',
          value: ['item1', 'item2', 'item3'],
        );

        await Future.delayed(Duration(milliseconds: 10));

        final copy = signal.copy;
        expect(copy, ['item1', 'item2', 'item3']);
        expect(identical(copy, signal.value),
            isFalse); // Should be different instances
      });
    });

    group('Special Cases', () {
      test('should handle null values in list', () async {
        final signal = PListSignal<String?>(
          key: 'nullable_list',
          value: ['item1', null, 'item2'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value, ['item1', null, 'item2']);
        expect(signal.value.length, 3);

        signal.add(null);
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['item1', null, 'item2', null]);
        expect(signal.value.length, 4);
      });

      test('should handle list with duplicate items', () async {
        final signal = PListSignal<String>(
          key: 'duplicates_test',
          value: ['item', 'item', 'item'],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 3);

        signal.remove('item'); // Should remove first occurrence
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value, ['item', 'item']);
        expect(signal.value.length, 2);
      });

      test('should handle large lists', () async {
        final largeList = List.generate(1000, (i) => 'item_$i');
        final signal = PListSignal<String>(
          key: 'large_list',
          value: largeList,
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 1000);
        expect(signal.value.first, 'item_0');
        expect(signal.value.last, 'item_999');
      });
    });

    group('Custom Serialization', () {
      test('should support custom serialization for complex objects', () async {
        final signal = PListSignal<Map<String, dynamic>>(
          key: 'custom_objects',
          value: [
            {'id': 1, 'name': 'Item 1'},
            {'id': 2, 'name': 'Item 2'},
          ],
        );

        await Future.delayed(Duration(milliseconds: 10));
        expect(signal.value.length, 2);
        expect(signal.value[0]['name'], 'Item 1');

        signal.add({'id': 3, 'name': 'Item 3'});
        await Future.delayed(Duration(milliseconds: 10));

        expect(signal.value.length, 3);
        expect(signal.value[2]['name'], 'Item 3');
      });
    });
  });
}
