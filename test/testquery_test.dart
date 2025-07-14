// This file tests our custom query system to make sure everything works correctly
// Tests help us catch bugs early and ensure our code behaves as expected

import 'package:flutter_test/flutter_test.dart';
import 'package:query_signals/query_signals/models/query_client_config.model.dart';
import 'package:query_signals/query_signals/models/query_error.model.dart';
import 'package:query_signals/query_signals/models/query_key.model.dart';
import 'package:query_signals/query_signals/models/query_mutation_options.model.dart';
import 'package:query_signals/query_signals/models/query_options.model.dart';
import 'package:query_signals/query_signals/client/query_client.dart';
import 'package:query_signals/storage/base_persisted_storage.abstract.dart';
import 'package:query_signals/query_signals/enums/query_status.enum.dart';
import 'package:signals/signals_flutter.dart';

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
  ) async =>
      _records[key] = records;

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
  final storage = MockStorage();

  // Initialize our query client with test configuration
  await QueryClient().init(
    config: QueryClientConfig(
      defaultStaleDuration: Duration(minutes: 1), // Short duration for testing
      defaultCacheDuration: Duration(minutes: 5),
      requestTimeout: Duration(seconds: 5),
    ),
    storage: storage,
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
    // PersistSignals.reset();
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

      // ACT: Perform the action we want to test
      final query = QueryClient().useQuery<List<TestPost>, List<dynamic>>(
        ['test-posts'], // Query key (unique identifier)
        mockFetchPosts, // Function to fetch data
        options: QueryOptions(
          transformer: (jsonList) => // Transform JSON to objects
              (jsonList).map((json) => TestPost.fromJson(json)).toList(),
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
      // Create a query that will fail
      final query = QueryClient().useQuery<String, String>(
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
          transformer: (jsonList) =>
              (jsonList).map((json) => TestPost.fromJson(json)).toList(),
        ),
      );

      await Future.delayed(Duration(milliseconds: 200));

      // Second query with same key should return the same instance
      final query2 = client.useQuery<List<TestPost>, List<dynamic>>(
        ['cached-posts'],
        mockFetchPosts,
        options: QueryOptions(
          transformer: (jsonList) =>
              (jsonList).map((json) => TestPost.fromJson(json)).toList(),
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
          transformer: (jsonList) =>
              (jsonList).map((json) => TestPost.fromJson(json)).toList(),
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

  // GROUP: Query Persistence Tests
  group('Query Persistence Tests', () {
    test('should persist and hydrate query data', () async {
      final storage = MockStorage();
      final client = QueryClient();
      await client.init(storage: storage);

      // Create initial query
      final query1 = client.useQuery<String, String>(
        ['persistence-test'],
        () async => 'cached data',
      );

      await Future.delayed(Duration(milliseconds: 200));
      expect(query1.data, 'cached data');

      // Simulate app restart by creating new client
      final newClient = QueryClient();
      await newClient.init(storage: storage);

      final query2 = newClient.useQuery<String, String>(
        ['persistence-test'],
        () async => 'fresh data',
      );

      await query2.waitForHydration();
      expect(query2.data, 'cached data', reason: 'Should load from cache');
    });

    test('should implement stale-while-revalidate behavior', () async {
      final client = QueryClient();
      int fetchCount = 0;

      final query = client.useQuery<String, String>(
        ['stale-revalidate'],
        () async {
          fetchCount++;
          await Future.delayed(Duration(milliseconds: 50));
          return 'data $fetchCount';
        },
        options: QueryOptions(
          staleDuration: Duration(milliseconds: 100),
          cacheDuration: Duration(minutes: 1),
        ),
      );

      // Initial fetch
      await Future.delayed(Duration(milliseconds: 100));
      expect(fetchCount, 1);
      expect(query.data, 'data 1');

      // Wait for staleness
      await Future.delayed(Duration(milliseconds: 150));
      expect(query.isStale, true);

      // Create new query - should show stale data and refetch in background
      final query2 = client.useQuery<String, String>(
        ['stale-revalidate'],
        () async {
          fetchCount++;
          return 'data $fetchCount';
        },
        options: QueryOptions(
          staleDuration: Duration(milliseconds: 100),
          cacheDuration: Duration(minutes: 1),
        ),
      );

      // Should immediately have stale data
      expect(query2.data, 'data 1');

      // Wait for background refresh
      await Future.delayed(Duration(milliseconds: 100));
      expect(fetchCount, 2);
      expect(query2.data, 'data 2');
    });
  });

  // GROUP: Query Prefetching Tests
  group('Query Prefetching Tests', () {
    test('should prefetch queries correctly', () async {
      final client = QueryClient();
      int fetchCount = 0;

      Future<String> mockFetch() async {
        fetchCount++;
        return 'prefetched data $fetchCount';
      }

      // Prefetch without creating a query
      await client.prefetchQuery<String, String>(
        ['prefetch-test'],
        mockFetch,
      );

      expect(fetchCount, 1);

      // Now create the actual query - should use prefetched data
      final query = client.useQuery<String, String>(
        ['prefetch-test'],
        mockFetch,
      );

      await query.waitForHydration();
      expect(query.data, 'prefetched data 1');
      expect(fetchCount, 1, reason: 'Should not fetch again');
    });
  });

  // GROUP: Background Refresh Tests
  group('Background Refresh Tests', () {
    test('should handle background refresh intervals', () async {
      final client = QueryClient();
      int fetchCount = 0;

      final query = client.useQuery<String, String>(
        ['background-refresh'],
        () async {
          fetchCount++;
          return 'data $fetchCount';
        },
        options: QueryOptions(
          refetchInterval: Duration(milliseconds: 100),
        ),
      );

      // Initial fetch
      await Future.delayed(Duration(milliseconds: 50));
      expect(fetchCount, 1);

      // Wait for background refresh
      await Future.delayed(Duration(milliseconds: 150));
      expect(fetchCount, 2);

      // Wait for another refresh
      await Future.delayed(Duration(milliseconds: 100));
      expect(fetchCount, 3);

      // Stop the query to prevent more refreshes
      query.dispose();
    });
  });

  // GROUP: Dependent Queries Tests
  group('Dependent Queries Tests', () {
    test('should handle dependent queries correctly', () async {
      final client = QueryClient();

      // First query
      final userQuery =
          client.useQuery<Map<String, dynamic>, Map<String, dynamic>>(
        ['user', 1],
        () async => {'id': 1, 'name': 'John', 'companyId': 5},
      );

      await Future.delayed(Duration(milliseconds: 100));

      // Dependent query
      final companyQuery =
          client.useQuery<Map<String, dynamic>, Map<String, dynamic>>(
        ['company', userQuery.data?['companyId']],
        () async {
          final companyId = userQuery.data?['companyId'];
          if (companyId == null) throw Exception('No company ID');
          return {'id': companyId, 'name': 'Acme Corp'};
        },
        options: QueryOptions(
          enabled: userQuery.data != null,
        ),
      );

      await Future.delayed(Duration(milliseconds: 100));

      expect(userQuery.status, QueryStatus.success);
      expect(companyQuery.status, QueryStatus.success);
      expect(companyQuery.data?['name'], 'Acme Corp');
    });
  });

  // GROUP: Complex Invalidation Tests
  group('Complex Invalidation Tests', () {
    test('should handle hierarchical invalidation patterns', () async {
      final client = QueryClient();

      // Create hierarchical queries
      final queries = [
        client.useQuery(['posts'], () async => 'posts data'),
        client.useQuery(['posts', 1], () async => 'post 1 data'),
        client.useQuery(['posts', 1, 'comments'], () async => 'comments data'),
        client.useQuery(['users'], () async => 'users data'),
      ];

      await Future.delayed(Duration(milliseconds: 200));

      // All should be fresh initially
      for (final query in queries) {
        expect(query.isStale, false);
      }

      // Invalidate posts queries
      client.invalidateQueries(['posts']);

      // Only posts queries should be stale
      expect(queries[0].isStale, true); // ['posts']
      expect(queries[1].isStale, true); // ['posts', 1]
      expect(queries[2].isStale, true); // ['posts', 1, 'comments']
      expect(queries[3].isStale, false); // ['users']
    });
  });

  // GROUP: Watch Signals Tests
  group('Watch Signals Tests', () {
    test('should refetch when watched signals change', () async {
      final client = QueryClient();
      int fetchCount = 0;
      final userId = signal(1);

      final query = client.useQuery<String, String>(
        ['user-data', userId.value],
        () async {
          fetchCount++;
          return 'user ${userId.value} data (fetch $fetchCount)';
        },
        options: QueryOptions(
          watchSignals: [userId],
        ),
      );

      await Future.delayed(Duration(milliseconds: 100));
      expect(fetchCount, 1);
      expect(query.data, 'user 1 data (fetch 1)');

      // Change watched signal
      userId.value = 2;
      await Future.delayed(Duration(milliseconds: 100));

      expect(fetchCount, 2);
      expect(query.data, 'user 2 data (fetch 2)');
    });
  });

  // GROUP: Query Timeout Tests
  group('Query Timeout Tests', () {
    test('should timeout slow queries', () async {
      final client = QueryClient();

      final query = client.useQuery<String, String>(
        ['timeout-test'],
        () async {
          await Future.delayed(Duration(seconds: 2));
          return 'slow data';
        },
        options: QueryOptions(
          requestTimeout: Duration(milliseconds: 100),
        ),
      );

      await Future.delayed(Duration(milliseconds: 200));

      expect(query.status, QueryStatus.timeout);
      expect(query.error?.type, QueryErrorType.timeout);
    });
  });

  // GROUP: Optimistic Updates Tests
  group('Optimistic Updates Tests', () {
    test('should handle optimistic updates with manual management', () async {
      final client = QueryClient();

      // Set up initial data
      final postsQuery = client.useQuery<List<TestPost>, List<dynamic>>(
        ['posts'],
        () async => [
          {'id': 1, 'title': 'Post 1', 'body': 'Body 1'},
          {'id': 2, 'title': 'Post 2', 'body': 'Body 2'},
        ],
        options: QueryOptions(
          transformer: (jsonList) =>
              jsonList.map((json) => TestPost.fromJson(json)).toList(),
        ),
      );

      await Future.delayed(Duration(milliseconds: 200));
      expect(postsQuery.data!.length, 2);

      // Optimistic update: add new post immediately
      final currentPosts = postsQuery.data!;
      final optimisticPost =
          TestPost(id: 999, title: 'Optimistic Post', body: 'Optimistic Body');
      client.setQueryData(['posts'], [...currentPosts, optimisticPost]);

      // Should immediately show optimistic update
      expect(postsQuery.data!.length, 3);
      expect(postsQuery.data!.any((p) => p.id == 999), true);

      // Create mutation that will replace optimistic update
      final createMutation = client.useMutation<TestPost, Map<String, dynamic>>(
        (data) async {
          await Future.delayed(Duration(milliseconds: 100));
          return TestPost.fromJson({...data, 'id': 3});
        },
        options: MutationOptions(
          onSuccess: (data) {
            // Replace optimistic update with real data
            final currentPosts =
                client.getQueryData<List<TestPost>>(['posts']) ?? [];
            final updatedPosts = currentPosts.where((p) => p.id != 999).toList()
              ..add(data as TestPost);
            client.setQueryData(['posts'], updatedPosts);
          },
        ),
      );

      await createMutation.mutate({'title': 'Real Post', 'body': 'Real Body'});

      // Should now have real data
      expect(postsQuery.data!.length, 3);
      expect(postsQuery.data!.any((p) => p.id == 3), true);
      expect(postsQuery.data!.any((p) => p.id == 999), false);
    });
  });

  // GROUP: Query Disposal Tests
  group('Query Disposal Tests', () {
    test('should dispose queries and clean up resources', () async {
      final client = QueryClient();

      final query = client.useQuery<String, String>(
        ['disposal-test'],
        () async => 'test data',
      );

      await Future.delayed(Duration(milliseconds: 100));
      expect(query.data, 'test data');

      // Dispose query
      query.dispose();

      // Query should be removed from client
      expect(client.getQueryData<String>(['disposal-test']), isNull);
    });
  });

  // GROUP: Query Enabled/Disabled Tests
  group('Query Enabled/Disabled Tests', () {
    test('should not execute disabled queries', () async {
      final client = QueryClient();
      int fetchCount = 0;

      final query = client.useQuery<String, String>(
        ['disabled-test'],
        () async {
          fetchCount++;
          return 'data';
        },
        options: QueryOptions(
          enabled: false,
        ),
      );

      await Future.delayed(Duration(milliseconds: 200));

      expect(fetchCount, 0, reason: 'Disabled queries should not execute');
      expect(query.status, QueryStatus.idle);
    });

    test('should execute query when enabled becomes true', () async {
      final client = QueryClient();
      int fetchCount = 0;
      bool isEnabled = false;

      final query = client.useQuery<String, String>(
        ['conditional-test'],
        () async {
          fetchCount++;
          return 'data $fetchCount';
        },
        options: QueryOptions(
          enabled: isEnabled,
        ),
      );

      await Future.delayed(Duration(milliseconds: 100));
      expect(fetchCount, 0);

      // Enable the query
      isEnabled = true;
      await query.refetch();

      expect(fetchCount, 1);
      expect(query.data, 'data 1');
    });
  });
}
