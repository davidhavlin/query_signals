// This file tests our custom query system to make sure everything works correctly
// Tests help us catch bugs early and ensure our code behaves as expected

import 'package:flutter_test/flutter_test.dart';
import 'package:persist_signals/testquery/query_client.dart';
import 'package:persist_signals/persist_signals.dart';
import 'package:persist_signals/storage/base_persisted_storage.abstract.dart';
import 'package:persist_signals/testquery/types/query_types.dart';

// Simple in-memory storage for testing
class MockStorage implements BasePersistedStorage {
  final Map<String, String> _data = {};
  final Map<String, List<Map<String, dynamic>>> _records = {};

  @override
  Future<void> init() async {}

  @override
  Future<String?> get(String key) async => _data[key];

  @override
  Future<void> set(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async {
    _data.clear();
    _records.clear();
  }

  @override
  Future<Map<String, dynamic>?> getRecord(String storeName, String id) async {
    final records = _records[storeName];
    if (records == null) return null;
    try {
      return records.firstWhere((r) => r['id'] == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRecords(String key) async =>
      _records[key] ?? [];

  @override
  Future<void> setRecords(
    String key,
    List<Map<String, dynamic>> records,
  ) async => _records[key] = records;

  @override
  Future<void> setRecord(
    String key,
    String id,
    Map<String, dynamic> record,
  ) async {
    _records[key] ??= [];
    final existingIndex = _records[key]!.indexWhere((r) => r['id'] == id);
    if (existingIndex >= 0) {
      _records[key]![existingIndex] = record;
    } else {
      _records[key]!.add(record);
    }
  }

  @override
  Future<void> deleteRecord(String key, String id) async {
    _records[key]?.removeWhere((r) => r['id'] == id);
  }

  @override
  Future<void> deleteRecords(String storeName, List<String> ids) async {
    for (final id in ids) {
      await deleteRecord(storeName, id);
    }
  }

  @override
  Future<void> clearStore(String storeName) async {
    _records.remove(storeName);
  }
}

// Mock data models for testing
// These are simple classes that represent the data we're working with
class TestPost {
  final int id;
  final String title;
  final String body;

  TestPost({required this.id, required this.title, required this.body});

  // Convert from JSON (like from an API)
  factory TestPost.fromJson(Map<String, dynamic> json) => TestPost(
    id: json['id'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  // Convert to JSON (for storage)
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};

  // Helper to check if two posts are the same
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestPost &&
          id == other.id &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => Object.hash(id, title, body);
}

// Mock API functions for testing
// These simulate real API calls but return test data immediately
Future<List<dynamic>> mockFetchPosts() async {
  // Simulate network delay
  await Future.delayed(Duration(milliseconds: 100));

  // Return fake post data
  return [
    {'id': 1, 'title': 'Test Post 1', 'body': 'Body 1'},
    {'id': 2, 'title': 'Test Post 2', 'body': 'Body 2'},
  ];
}

Future<Map<String, dynamic>> mockFetchPost(int id) async {
  await Future.delayed(Duration(milliseconds: 50));
  return {'id': id, 'title': 'Test Post $id', 'body': 'Body $id'};
}

Future<Map<String, dynamic>> mockCreatePost(Map<String, dynamic> data) async {
  await Future.delayed(Duration(milliseconds: 50));
  return {
    ...data,
    'id': 99, // Simulate server-generated ID
  };
}

// This function runs before each test to set up a clean environment
Future<void> setupQueryClient() async {
  // Initialize persist_signals first (required for caching)
  await PersistSignals.init(MockStorage());

  // Initialize our query client with test configuration
  await QueryClient().init(
    QueryClientConfig(
      defaultStaleDuration: Duration(minutes: 1), // Short duration for testing
      defaultCacheDuration: Duration(minutes: 5),
      requestTimeout: Duration(seconds: 5),
    ),
  );
}

void main() {
  // This is the main test function - all our tests go inside here

  // setUpAll runs once before ALL tests
  setUpAll(() async {
    await setupQueryClient();
  });

  // tearDownAll runs once after ALL tests to clean up
  tearDownAll(() {
    QueryClient().disposeAll();
    // Reset PersistSignals for clean state
    PersistSignals.reset();
  });

  // setUp runs before EACH test to ensure clean state
  setUp(() {
    // Clear any existing data between tests
    QueryClient().removeQueries(null);
  });

  // GROUP: Query Tests
  // Groups help organize related tests together
  group('Query Tests', () {
    // TEST: Basic query functionality
    test('should create and execute a basic query', () async {
      // ARRANGE: Set up the test data and dependencies
      final client = QueryClient();

      // ACT: Perform the action we want to test
      final query = client.useQuery<List<TestPost>, List<dynamic>>(
        ['test-posts'], // Query key (unique identifier)
        mockFetchPosts, // Function to fetch data
        options: QueryOptions(
          transformer:
              (jsonList) => // Transform JSON to objects
              (jsonList as List)
                  .map((json) => TestPost.fromJson(json))
                  .toList(),
        ),
      );

      // Wait for the query to complete
      await Future.delayed(Duration(milliseconds: 200));

      // ASSERT: Check that the results are what we expected
      expect(
        query.status,
        QueryStatus.success,
        reason: 'Query should be successful',
      );
      expect(query.data, isNotNull, reason: 'Query should have data');
      expect(query.data!.length, 2, reason: 'Should have 2 posts');
      expect(
        query.data![0].title,
        'Test Post 1',
        reason: 'First post title should match',
      );
      expect(query.isLoading, false, reason: 'Query should not be loading');
      expect(query.isError, false, reason: 'Query should not have errors');
    });

    // TEST: Query error handling
    test('should handle query errors correctly', () async {
      final client = QueryClient();

      // Create a query that will fail
      final query = client.useQuery<String, String>(
        ['failing-query'],
        () async {
          throw Exception('Simulated API error');
        },
      );

      // Wait for the query to fail
      await Future.delayed(Duration(milliseconds: 200));

      // Check error handling
      expect(
        query.status,
        QueryStatus.error,
        reason: 'Query should be in error state',
      );
      expect(query.error, isNotNull, reason: 'Query should have an error');
      expect(
        query.error!.type,
        QueryErrorType.unknown,
        reason: 'Should be unknown error type',
      );
      expect(query.data, isNull, reason: 'Query should have no data');
      expect(query.isError, true, reason: 'isError should be true');
    });

    // TEST: Query caching
    test('should cache query results', () async {
      final client = QueryClient();

      // First query
      final query1 = client.useQuery<List<TestPost>, List<dynamic>>(
        ['cached-posts'],
        mockFetchPosts,
        options: QueryOptions(
          transformer: (jsonList) => (jsonList as List)
              .map((json) => TestPost.fromJson(json))
              .toList(),
        ),
      );

      await Future.delayed(Duration(milliseconds: 200));

      // Second query with same key should return the same instance
      final query2 = client.useQuery<List<TestPost>, List<dynamic>>(
        ['cached-posts'],
        mockFetchPosts,
        options: QueryOptions(
          transformer: (jsonList) => (jsonList as List)
              .map((json) => TestPost.fromJson(json))
              .toList(),
        ),
      );

      // Should be the exact same query object (cached)
      expect(
        identical(query1, query2),
        true,
        reason: 'Queries with same key should be identical',
      );
      expect(
        query2.data,
        isNotNull,
        reason: 'Cached query should have data immediately',
      );
    });

    // TEST: Query invalidation
    test('should invalidate queries correctly', () async {
      final client = QueryClient();

      final query = client.useQuery<List<TestPost>, List<dynamic>>(
        ['invalidation-test'],
        mockFetchPosts,
        options: QueryOptions(
          transformer: (jsonList) => (jsonList as List)
              .map((json) => TestPost.fromJson(json))
              .toList(),
        ),
      );

      await Future.delayed(Duration(milliseconds: 200));

      // Check query is successful and not stale
      expect(query.status, QueryStatus.success);
      expect(query.isStale, false, reason: 'Fresh query should not be stale');

      // Invalidate the query
      client.invalidateQueries(['invalidation-test']);

      // Query should now be marked as stale
      expect(query.isStale, true, reason: 'Invalidated query should be stale');
    });
  });

  // GROUP: Mutation Tests
  group('Mutation Tests', () {
    // TEST: Basic mutation functionality
    test('should create and execute a mutation', () async {
      final client = QueryClient();

      // Create a mutation for creating posts
      final createMutation = client.useMutation<TestPost, Map<String, dynamic>>(
        (variables) async {
          final result = await mockCreatePost(variables);
          return TestPost.fromJson(result);
        },
      );

      // Execute the mutation
      final result = await createMutation.mutate({
        'title': 'New Post',
        'body': 'New post body',
      });

      // Check results
      expect(
        createMutation.status,
        QueryStatus.success,
        reason: 'Mutation should be successful',
      );
      expect(
        createMutation.data,
        isNotNull,
        reason: 'Mutation should have result data',
      );
      expect(result, isNotNull, reason: 'Mutation should return result');
      expect(result!.id, 99, reason: 'Should have server-generated ID');
      expect(result.title, 'New Post', reason: 'Title should match input');
    });

    // TEST: Mutation error handling
    test('should handle mutation errors correctly', () async {
      final client = QueryClient();

      final mutation = client.useMutation<String, String>((variables) async {
        throw Exception('Mutation failed');
      });

      // Execute failing mutation
      final result = await mutation.mutate('test');

      // Check error handling
      expect(
        mutation.status,
        QueryStatus.error,
        reason: 'Mutation should be in error state',
      );
      expect(mutation.error, isNotNull, reason: 'Mutation should have error');
      expect(result, isNull, reason: 'Failed mutation should return null');
      expect(mutation.isError, true, reason: 'isError should be true');
    });

    // TEST: Mutation callbacks
    test('should execute mutation callbacks correctly', () async {
      final client = QueryClient();
      bool onSuccessCalled = false;
      bool onSettledCalled = false;

      final mutation = client.useMutation<String, String>(
        (variables) async => 'Success: $variables',
        options: MutationOptions(
          onSuccess: (data) {
            onSuccessCalled = true;
            expect(
              data,
              'Success: test',
              reason: 'Success callback should receive correct data',
            );
          },
          onSettled: () {
            onSettledCalled = true;
          },
        ),
      );

      await mutation.mutate('test');

      // Check callbacks were called
      expect(
        onSuccessCalled,
        true,
        reason: 'onSuccess callback should be called',
      );
      expect(
        onSettledCalled,
        true,
        reason: 'onSettled callback should be called',
      );
    });
  });

  // GROUP: QueryClient Tests
  group('QueryClient Tests', () {
    // TEST: Singleton behavior
    test('should maintain singleton pattern', () {
      final client1 = QueryClient();
      final client2 = QueryClient();

      // Should be the exact same instance
      expect(
        identical(client1, client2),
        true,
        reason: 'QueryClient should be singleton',
      );
    });

    // TEST: Configuration
    test('should apply configuration correctly', () async {
      final client = QueryClient();

      // Check default configuration
      expect(client.config.defaultStaleDuration, Duration(minutes: 1));
      expect(client.config.requestTimeout, Duration(seconds: 5));
    });

    // TEST: Query data manipulation
    test('should set and get query data manually', () async {
      final client = QueryClient();
      final testData = [TestPost(id: 1, title: 'Manual', body: 'Test')];

      // First create a query so we have something to manipulate
      final query = client.useQuery<List<TestPost>, List<dynamic>>([
        'manual-data',
      ], () async => []);

      // Wait for initial query to complete
      await Future.delayed(Duration(milliseconds: 100));

      // Now set data manually (optimistic update)
      client.setQueryData(['manual-data'], testData);

      // Get data back from query object
      expect(query.data, isNotNull, reason: 'Query should have data');
      expect(query.data!.length, 1, reason: 'Should have one item');
      expect(
        query.data![0].title,
        'Manual',
        reason: 'Data should match what was set',
      );

      // Also test the direct getQueryData method
      final retrievedData = client.getQueryData<List<TestPost>>([
        'manual-data',
      ]);
      expect(retrievedData, isNotNull, reason: 'Should retrieve set data');
    });
  });

  // GROUP: QueryKey Tests
  group('QueryKey Tests', () {
    // TEST: QueryKey equality
    test('should handle QueryKey equality correctly', () {
      final key1 = QueryKey(['posts', 1]);
      final key2 = QueryKey(['posts', 1]);
      final key3 = QueryKey(['posts', 2]);

      // Same keys should be equal
      expect(key1 == key2, true, reason: 'Identical keys should be equal');
      expect(
        key1.hashCode == key2.hashCode,
        true,
        reason: 'Equal keys should have same hash',
      );

      // Different keys should not be equal
      expect(key1 == key3, false, reason: 'Different keys should not be equal');
    });

    // TEST: QueryKey caching
    test('should cache hash codes for performance', () {
      final key = QueryKey(['test', 'key']);

      // Get hash code twice
      final hash1 = key.hashCode;
      final hash2 = key.hashCode;

      // Should be the same (cached)
      expect(
        hash1,
        hash2,
        reason: 'Hash codes should be cached and consistent',
      );
    });
  });

  // GROUP: Error Handling Tests
  group('Error Handling Tests', () {
    // TEST: QueryError creation
    test('should create QueryError with correct properties', () {
      final error = QueryError(
        'Test error message',
        QueryErrorType.network,
        Exception('Original error'),
      );

      expect(error.message, 'Test error message');
      expect(error.type, QueryErrorType.network);
      expect(error.originalError, isA<Exception>());
      expect(
        error.toString().contains('network'),
        true,
        reason: 'String should contain error type',
      );
    });

    // TEST: Network error detection
    test('should categorize network errors correctly', () async {
      final client = QueryClient();

      final query = client.useQuery<String, String>(
        ['network-error-test'],
        () async {
          throw Exception('network connection failed');
        },
      );

      await Future.delayed(Duration(milliseconds: 200));

      expect(
        query.error!.type,
        QueryErrorType.network,
        reason: 'Should detect network errors',
      );
      expect(
        query.status,
        QueryStatus.networkError,
        reason: 'Should set network error status',
      );
    });

    // TEST: Timeout error detection
    test('should categorize timeout errors correctly', () async {
      final client = QueryClient();

      final query = client.useQuery<String, String>(
        ['timeout-error-test'],
        () async {
          throw Exception('timeout occurred');
        },
      );

      await Future.delayed(Duration(milliseconds: 200));

      expect(
        query.error!.type,
        QueryErrorType.timeout,
        reason: 'Should detect timeout errors',
      );
      expect(
        query.status,
        QueryStatus.timeout,
        reason: 'Should set timeout status',
      );
    });
  });

  // GROUP: Performance Tests
  group('Performance Tests', () {
    // TEST: Request deduplication
    test('should deduplicate simultaneous requests', () async {
      final client = QueryClient();
      int apiCallCount = 0;

      // Create a query function that counts calls
      Future<String> countingFetch() async {
        apiCallCount++;
        await Future.delayed(Duration(milliseconds: 100));
        return 'Result $apiCallCount';
      }

      final query = client.useQuery<String, String>([
        'dedup-test',
      ], countingFetch);

      // Start multiple refetches simultaneously
      final futures = [query.refetch(), query.refetch(), query.refetch()];

      await Future.wait(futures);

      // Should only call API once due to deduplication
      expect(
        apiCallCount,
        1,
        reason: 'Should deduplicate simultaneous requests',
      );
    });
  });
}
