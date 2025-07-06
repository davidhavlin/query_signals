import 'package:flutter_test/flutter_test.dart';
import 'package:persist_signals/p_signals/client/p_signals_client.dart';
import 'package:persist_signals/p_signals/p_complex_list_signal.dart';

import 'mock_storage.dart';
import 'test_models.dart';

void main() {
  group('PComplexListSignal Tests', () {
    late MockStorage mockStorage;

    setUp(() {
      mockStorage = MockStorage();
      PSignalsClient.init(mockStorage);
    });

    tearDown(() {
      PSignalsClient.reset();
      mockStorage.reset();
    });

    group('Basic Operations', () {
      test('should initialize with empty list', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        expect(signal.length, 0);
        expect(signal.isHydrated, isTrue);
        expect(signal.isLoading, isFalse);
      });

      test('should add items and save individual records', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        signal.add(TestUser.sample);
        expect(signal.length, 1);
        expect(signal.first.id, TestUser.sample.id);

        // Wait for async save
        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 1);
      });

      test('should update existing item when adding with same ID', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        signal.add(TestUser.sample);
        await Future(() {});
        expect(signal.length, 1);

        final updatedUser = TestUser.sample.copyWith(name: 'Updated Name');
        signal.add(updatedUser);

        expect(signal.length, 1); // Still just one item
        expect(signal.first.name, 'Updated Name');

        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 1);
      });

      test('should add multiple items with addAll', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        final users = [TestUser.sample, TestUser.sampleInactive];
        signal.addAll(users);

        expect(signal.length, 2);
        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 2);
      });

      test('should remove items and delete records', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        signal.add(TestUser.sample);
        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 1);

        signal.remove(TestUser.sample);
        expect(signal.length, 0);

        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 0);
      });

      test('should clear all items and storage', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        signal.addAll([TestUser.sample, TestUser.sampleInactive]);
        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 2);

        signal.clear();
        expect(signal.length, 0);

        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 0);
      });
    });

    group('Individual Record Operations', () {
      test('should update item by ID', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.add(TestUser.sample);
        await Future(() {});

        final updatedUser = await signal.updateItem(TestUser.sample.id, {
          'name': 'Updated Name',
          'age': 35,
        });

        expect(updatedUser, isNotNull);
        expect(updatedUser!.name, 'Updated Name');
        expect(updatedUser.age, 35);
        expect(signal.first.name, 'Updated Name');
      });

      test('should create new item if ID not found in updateItem', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        final newUser = await signal.updateItem('new-id', {
          'id': 'new-id',
          'name': 'New User',
          'email': 'new@example.com',
          'age': 25,
          'isActive': true,
        });

        expect(newUser, isNotNull);
        expect(signal.length, 1);
        expect(signal.first.id, 'new-id');
      });

      test('should remove item by ID', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.add(TestUser.sample);
        await Future(() {});

        final removed = signal.removeById(TestUser.sample.id);
        expect(removed, isTrue);
        expect(signal.length, 0);

        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 0);
      });

      test('should find item by ID', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.add(TestUser.sample);

        final found = signal.findById(TestUser.sample.id);
        expect(found, isNotNull);
        expect(found!.id, TestUser.sample.id);

        final notFound = signal.findById('non-existent');
        expect(notFound, isNull);
      });
    });

    group('Batch Operations', () {
      test('should batch update multiple items', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.addAll([TestUser.sample, TestUser.sampleInactive]);
        await Future(() {});

        final updates = [
          {'id': TestUser.sample.id, 'name': 'Batch Updated 1'},
          {'id': TestUser.sampleInactive.id, 'name': 'Batch Updated 2'},
        ];

        final results = await signal.batchUpdate(updates);

        expect(results.length, 2);
        expect(results[0]?.name, 'Batch Updated 1');
        expect(results[1]?.name, 'Batch Updated 2');
        expect(signal[0].name, 'Batch Updated 1');
        expect(signal[1].name, 'Batch Updated 2');
      });
    });

    group('Optimistic Updates', () {
      test('should perform optimistic updates by default', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
          optimisticUpdates: true,
        );

        await signal.waitForHydration();
        signal.add(TestUser.sample);
        await Future(() {});

        // Update should be immediate
        await signal
            .updateItem(TestUser.sample.id, {'name': 'Optimistic Update'});
        expect(signal.first.name, 'Optimistic Update');
      });

      test('should rollback on update error', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
          optimisticUpdates: true,
        );

        await signal.waitForHydration();
        signal.add(TestUser.sample);
        await Future(() {});

        final originalName = signal.first.name;

        // Simulate storage error
        mockStorage.simulateSetError();

        final result = await signal
            .updateItem(TestUser.sample.id, {'name': 'Should Fail'});

        expect(result, isNull); // Update failed
        expect(signal.first.name, originalName); // Rolled back
        expect(signal.lastError, isNotNull);
      });
    });

    group('Querying and Filtering', () {
      test('should filter items by predicate', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.addAll([TestUser.sample, TestUser.sampleInactive]);

        final activeUsers = signal.filter((user) => user.isActive);
        expect(activeUsers.length, 1);
        expect(activeUsers.first.isActive, isTrue);
      });

      test('should find items by field value', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.addAll([TestUser.sample, TestUser.sampleInactive]);

        final johnUsers = signal.findByField('name', 'John Doe');
        expect(johnUsers.length, 1);
        expect(johnUsers.first.name, 'John Doe');
      });

      test('should sort items by field', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.addAll([TestUser.sample, TestUser.sampleInactive]);

        signal.sortByField('age', ascending: true);
        expect(signal.first.age, lessThanOrEqualTo(signal.last.age));

        signal.sortByField('age', ascending: false);
        expect(signal.first.age, greaterThanOrEqualTo(signal.last.age));
      });

      test('should get unique field values', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.addAll([TestUser.sample, TestUser.sampleInactive]);

        final uniqueAges = signal.getUniqueValues('age');
        expect(uniqueAges.length, 2);
        expect(uniqueAges.contains(30), isTrue);
        expect(uniqueAges.contains(25), isTrue);
      });
    });

    group('Hydration and Persistence', () {
      test('should hydrate from existing storage data', () async {
        // Pre-populate storage
        await mockStorage.setRecord('users', 'user1', TestUser.sample.toJson());
        await mockStorage.setRecord(
            'users', 'user2', TestUser.sampleInactive.toJson());

        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        expect(signal.length, 2);
        expect(signal.any((u) => u.id == 'user1'), isTrue);
        expect(signal.any((u) => u.id == 'user2'), isTrue);
      });

      test('should refresh data from storage', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        expect(signal.length, 0);

        // Manually add data to storage
        await mockStorage.setRecord(
            'users', 'external', TestUser.sample.toJson());

        await signal.refresh();
        expect(signal.length, 1);
        expect(signal.first.id, TestUser.sample.id);
      });

      test('should get item directly from storage', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.add(TestUser.sample);
        await Future(() {});

        final fromStorage = await signal.getItemFromStorage(TestUser.sample.id);
        expect(fromStorage, isNotNull);
        expect(fromStorage!.id, TestUser.sample.id);
        expect(fromStorage.name, TestUser.sample.name);
      });
    });

    group('Error Handling', () {
      test('should handle storage errors gracefully', () async {
        final errorMessages = <String>[];
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
          onError: (error, stackTrace) {
            errorMessages.add(error.toString());
          },
        );

        await signal.waitForHydration();

        mockStorage.simulateSetError();
        signal.add(TestUser.sample);

        await Future(() {});
        expect(errorMessages, isNotEmpty);
        expect(signal.lastError, isNotNull);
      });

      test('should provide stats about the signal', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.add(TestUser.sample);

        final stats = signal.stats;
        expect(stats['count'], 1);
        expect(stats['isHydrated'], isTrue);
        expect(stats['isLoading'], isFalse);
        expect(stats['hasError'], isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle removeWhere correctly', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();
        signal.addAll([TestUser.sample, TestUser.sampleInactive]);
        await Future(() {});

        signal.removeWhere((user) => !user.isActive);
        expect(signal.length, 1);
        expect(signal.first.isActive, isTrue);

        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 1);
      });

      test('should handle concurrent modifications', () async {
        final signal = PComplexListSignal<TestUser>(
          key: 'users',
          fromJson: TestUser.fromJson,
        );

        await signal.waitForHydration();

        // Add multiple items rapidly
        for (int i = 0; i < 5; i++) {
          signal.add(TestUser.sample.copyWith(id: 'user$i'));
        }

        expect(signal.length, 5);

        await Future(() {});
        expect(mockStorage.getRecordCount('users'), 5);
      });
    });
  });
}
