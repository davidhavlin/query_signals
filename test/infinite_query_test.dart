import 'package:flutter_test/flutter_test.dart';
import 'package:query_signals/query_signals/models/infinite_query_options.model.dart';
import 'package:query_signals/query_signals/client/query_client.dart';
import 'package:query_signals/p_signals/client/p_signals_client.dart';
import 'package:query_signals/storage/base_persisted_storage.abstract.dart';
import 'package:query_signals/query_signals/enums/query_status.enum.dart';

/// Simple in-memory storage for testing
class TestStorage extends BasePersistedStorage {
  final Map<String, String> _data = {};
  final Map<String, Map<String, Map<String, dynamic>>> _records = {};

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
  Future<void> setRecord(
    String storeName,
    String id,
    Map<String, dynamic> data,
  ) async {
    _records[storeName] ??= {};
    _records[storeName]![id] = data;
  }

  @override
  Future<Map<String, dynamic>?> getRecord(String storeName, String id) async {
    return _records[storeName]?[id];
  }

  @override
  Future<void> deleteRecord(String storeName, String id) async {
    _records[storeName]?.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getRecords(String storeName) async {
    return _records[storeName]?.values.toList() ?? [];
  }

  @override
  Future<void> setRecords(
    String storeName,
    List<Map<String, dynamic>> records,
  ) async {
    _records[storeName] = {};
    for (final record in records) {
      final id = record['id']?.toString();
      if (id != null) {
        _records[storeName]![id] = record;
      }
    }
  }

  @override
  Future<void> deleteRecords(String storeName, List<String> ids) async {
    for (final id in ids) {
      _records[storeName]?.remove(id);
    }
  }

  @override
  Future<void> clearStore(String storeName) async {
    _records[storeName]?.clear();
  }
}

/// Mock page data for testing
class MockPage {
  final List<String> items;
  final bool hasMore;
  final int page;

  MockPage({required this.items, required this.hasMore, required this.page});

  factory MockPage.fromJson(Map<String, dynamic> json) {
    return MockPage(
      items: List<String>.from(json['items']),
      hasMore: json['hasMore'],
      page: json['page'],
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items,
        'hasMore': hasMore,
        'page': page,
      };
}

void main() {
  group('InfiniteQuery Tests', () {
    late QueryClient client;

    setUpAll(() async {
      final storage = TestStorage();
      client = QueryClient();
      await client.init(storage: storage);
    });

    setUp(() {
      // Clear any existing queries before each test
      client.removeQueries(null);
    });

    test('should fetch first page on initialization', () async {
      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite'],
        (pageParam) async {
          await Future.delayed(Duration(milliseconds: 10));
          return {
            'items': ['item${pageParam}_1', 'item${pageParam}_2'],
            'hasMore': pageParam < 2,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) =>
              lastPage.hasMore ? lastPage.page + 1 : null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch to complete
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 20));

      expect(infiniteQuery.isSuccess, true);
      expect(infiniteQuery.data?.pages.length, 1);
      expect(infiniteQuery.data?.pages.first.items, ['item0_1', 'item0_2']);
      expect(infiniteQuery.hasNextPage, true);
    });

    test('should fetch next page correctly', () async {
      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite-next'],
        (pageParam) async {
          await Future.delayed(Duration(milliseconds: 10));
          return {
            'items': ['item${pageParam}_1', 'item${pageParam}_2'],
            'hasMore': pageParam < 2,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) =>
              lastPage.hasMore ? lastPage.page + 1 : null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 20));

      expect(infiniteQuery.hasNextPage, true);

      // Fetch next page
      await infiniteQuery.fetchNextPage();
      await Future.delayed(Duration(milliseconds: 20));

      expect(infiniteQuery.data?.pages.length, 2);
      expect(infiniteQuery.data?.pages[0].items, ['item0_1', 'item0_2']);
      expect(infiniteQuery.data?.pages[1].items, ['item1_1', 'item1_2']);
      expect(infiniteQuery.hasNextPage, true);
    });

    test('should detect when no more pages available', () async {
      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite-end'],
        (pageParam) async {
          await Future.delayed(Duration(milliseconds: 10));
          return {
            'items': ['item${pageParam}_1', 'item${pageParam}_2'],
            'hasMore': pageParam < 1, // Only 2 pages total
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) =>
              lastPage.hasMore ? lastPage.page + 1 : null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 20));

      // Fetch next page
      await infiniteQuery.fetchNextPage();
      await Future.delayed(Duration(milliseconds: 20));

      expect(infiniteQuery.data?.pages.length, 2);
      expect(infiniteQuery.hasNextPage, false);

      // Try to fetch next page - should not add more pages
      await infiniteQuery.fetchNextPage();
      await Future.delayed(Duration(milliseconds: 20));

      expect(infiniteQuery.data?.pages.length, 2); // Still 2 pages
    });

    test('should handle flatMap correctly', () async {
      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite-flatmap'],
        (pageParam) async {
          await Future.delayed(Duration(milliseconds: 10));
          return {
            'items': [
              'item${pageParam}_1',
              'item${pageParam}_2',
              'item${pageParam}_3',
            ],
            'hasMore': pageParam < 1,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) =>
              lastPage.hasMore ? lastPage.page + 1 : null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 20));

      // Fetch next page
      await infiniteQuery.fetchNextPage();
      await Future.delayed(Duration(milliseconds: 20));

      // Test flatMap functionality
      final allItems = infiniteQuery.data?.flatMap((page) => page.items) ?? [];

      expect(allItems.length, 6); // 3 items per page × 2 pages
      expect(allItems, [
        'item0_1',
        'item0_2',
        'item0_3',
        'item1_1',
        'item1_2',
        'item1_3',
      ]);
    });

    test('should handle refetch correctly', () async {
      int callCount = 0;

      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite-refetch'],
        (pageParam) async {
          callCount++;
          await Future.delayed(Duration(milliseconds: 10));
          return {
            'items': ['item${pageParam}_${callCount}'],
            'hasMore': false,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) => null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 20));

      expect(callCount, 1);
      expect(infiniteQuery.data?.pages.first.items, ['item0_1']);

      // Refetch should reset and fetch first page again
      await infiniteQuery.refetch();
      await Future.delayed(Duration(milliseconds: 20));

      expect(callCount, 2);
      expect(infiniteQuery.data?.pages.length, 1);
      expect(infiniteQuery.data?.pages.first.items, ['item0_2']);
    });

    test('should handle errors correctly', () async {
      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite-error'],
        (pageParam) async {
          if (pageParam == 1) {
            throw Exception('Simulated error for page 1');
          }
          return {
            'items': ['item${pageParam}_1'],
            'hasMore': true,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) => lastPage.page + 1,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch (should succeed)
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 20));

      expect(infiniteQuery.isSuccess, true);
      expect(infiniteQuery.data?.pages.length, 1);

      // Fetch next page (should fail)
      await infiniteQuery.fetchNextPage();
      await Future.delayed(Duration(milliseconds: 20));

      expect(infiniteQuery.error, isNotNull);
      expect(
        infiniteQuery.error!.message,
        contains('Simulated error for page 1'),
      );
      // First page should still be available
      expect(infiniteQuery.data?.pages.length, 1);
    });

    test('should track isFetchingNextPage state correctly', () async {
      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite-loading'],
        (pageParam) async {
          await Future.delayed(Duration(milliseconds: 50)); // Longer delay
          return {
            'items': ['item${pageParam}_1'],
            'hasMore': pageParam < 1,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) =>
              lastPage.hasMore ? lastPage.page + 1 : null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 60));

      expect(infiniteQuery.isFetchingNextPage, false);

      // Start fetching next page
      final fetchFuture = infiniteQuery.fetchNextPage();

      // Should be in loading state
      expect(infiniteQuery.isFetchingNextPage, true);

      // Wait for completion
      await fetchFuture;
      await Future.delayed(Duration(milliseconds: 10));

      expect(infiniteQuery.isFetchingNextPage, false);
    });

    test('should prevent duplicate fetchNextPage calls', () async {
      int callCount = 0;

      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-infinite-dedup'],
        (pageParam) async {
          callCount++;
          await Future.delayed(Duration(milliseconds: 30));
          return {
            'items': ['item${pageParam}_${callCount}'],
            'hasMore': pageParam < 2,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) =>
              lastPage.hasMore ? lastPage.page + 1 : null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 40));

      expect(callCount, 1);

      // Start multiple fetchNextPage calls simultaneously
      final futures = [
        infiniteQuery.fetchNextPage(),
        infiniteQuery.fetchNextPage(),
        infiniteQuery.fetchNextPage(),
      ];

      await Future.wait(futures);
      await Future.delayed(Duration(milliseconds: 10));

      // Should only have called the fetch function one more time
      expect(callCount, 2);
      expect(infiniteQuery.data?.pages.length, 2);
    });

    test('should support QueryClient infinite query methods', () async {
      final infiniteQuery =
          client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
        ['test-client-methods'],
        (pageParam) async {
          await Future.delayed(Duration(milliseconds: 10));
          return {
            'items': ['item${pageParam}_1', 'item${pageParam}_2'],
            'hasMore': pageParam < 1,
            'page': pageParam,
          };
        },
        options: InfiniteQueryOptions(
          transformer: (json) => MockPage.fromJson(json),
          getNextPageParam: (lastPage, allPages) =>
              lastPage.hasMore ? lastPage.page + 1 : null,
          initialPageParam: 0,
        ),
      );

      // Wait for initial fetch
      await infiniteQuery.waitForHydration();
      await Future.delayed(Duration(milliseconds: 20));

      // Test getInfiniteQueryData
      final data = client.getInfiniteQueryData<MockPage>([
        'test-client-methods',
      ]);
      expect(data?.pages.length, 1);
      expect(data?.pages.first.items, ['item0_1', 'item0_2']);

      // Test setInfiniteQueryData // TODO: fix this
      // final newData = InfiniteData<MockPage>(
      //   pages: [
      //     MockPage(items: ['custom1', 'custom2'], hasMore: false, page: 0),
      //   ],
      //   pageParams: [0],
      // );

      // // Call setData directly to test
      // infiniteQuery.setData(newData);

      // // Test that the change is reflected
      // expect(infiniteQuery.data?.pages.first.items, ['custom1', 'custom2']);

      // Test hasInfiniteQuery
      expect(client.hasInfiniteQuery(['test-client-methods']), true);
      expect(client.hasInfiniteQuery(['non-existent']), false);

      // Test waitForHydration includes infinite queries
      await client.waitForHydration(); // Should not throw

      // Test disposeQuery handles infinite queries
      client.disposeQuery(['test-client-methods']);
      final disposedData = client.getInfiniteQueryData<MockPage>([
        'test-client-methods',
      ]);
      expect(disposedData, null);
    });

    // GROUP: Advanced Infinite Query Tests
    group('Advanced Infinite Query Tests', () {
      test('should handle previous page fetching', () async {
        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['test-previous-page'],
          (pageParam) async {
            await Future.delayed(Duration(milliseconds: 10));
            return {
              'items': ['item${pageParam}_1', 'item${pageParam}_2'],
              'hasMore': pageParam < 3,
              'page': pageParam,
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? lastPage.page + 1 : null,
            getPreviousPageParam: (firstPage, allPages) =>
                firstPage.page > 0 ? firstPage.page - 1 : null,
            initialPageParam: 1, // Start from page 1
          ),
        );

        // Wait for initial fetch
        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 1);
        expect(infiniteQuery.data?.pages.first.page, 1);
        expect(infiniteQuery.hasPreviousPage, true);

        // Fetch previous page
        await infiniteQuery.fetchPreviousPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 2);
        expect(infiniteQuery.data?.pages.first.page, 0); // Should be prepended
        expect(infiniteQuery.data?.pages.last.page, 1);
      });

      test('should handle complex page parameters', () async {
        final infiniteQuery = client.useInfiniteQuery<MockPage,
            Map<String, dynamic>, Map<String, dynamic>>(
          ['test-complex-params'],
          (pageParam) async {
            await Future.delayed(Duration(milliseconds: 10));
            final cursor = pageParam['cursor'] as String?;
            final limit = pageParam['limit'] as int;

            return {
              'items': List.generate(
                limit,
                (i) => 'item_${cursor ?? "start"}_$i',
              ),
              'hasMore': cursor != 'end',
              'page': 0, // Not used for complex params
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) => lastPage.hasMore
                ? {'cursor': 'page_${allPages.length}', 'limit': 3}
                : null,
            initialPageParam: {'cursor': null, 'limit': 3},
          ),
        );

        // Wait for initial fetch
        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 1);
        expect(infiniteQuery.data?.pages.first.items.length, 3);

        // Fetch next page with complex param
        await infiniteQuery.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 2);
        expect(infiniteQuery.data?.pages.last.items.first, contains('page_1'));
      });

      test('should persist infinite query data across restarts', () async {
        final storage = TestStorage();
        await storage.init();

        // Create first client and fetch data
        final client1 = QueryClient();
        await client1.init(storage: storage);

        final query1 =
            client1.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['persist-infinite'],
          (pageParam) async => {
            'items': ['persisted_item_${pageParam}'],
            'hasMore': pageParam < 1,
            'page': pageParam,
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? lastPage.page + 1 : null,
            initialPageParam: 0,
          ),
        );

        await query1.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        await query1.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(query1.data?.pages.length, 2);

        // Create new client (simulate restart)
        final client2 = QueryClient();
        await client2.init(storage: storage);

        final query2 =
            client2.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['persist-infinite'],
          (pageParam) async => {
            'items': ['fresh_item_${pageParam}'],
            'hasMore': false,
            'page': pageParam,
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) => null,
            initialPageParam: 0,
          ),
        );

        await query2.waitForHydration();

        // Should load from cache
        expect(query2.data?.pages.length, 2);
        expect(
          query2.data?.pages.first.items.first,
          'persisted_item_0',
          reason: 'Should load persisted data',
        );
      });

      test('should handle background refresh correctly', () async {
        int fetchCount = 0;

        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['test-background-refresh'],
          (pageParam) async {
            fetchCount++;
            await Future.delayed(Duration(milliseconds: 10));
            return {
              'items': ['item${pageParam}_fetch${fetchCount}'],
              'hasMore': pageParam < 1,
              'page': pageParam,
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? lastPage.page + 1 : null,
            initialPageParam: 0,
            staleDuration: Duration(milliseconds: 50),
          ),
        );

        // Initial fetch
        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        // Fetch next page
        await infiniteQuery.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(fetchCount, 2); // One for each page
        expect(infiniteQuery.data?.pages.length, 2);

        // Wait for staleness
        await Future.delayed(Duration(milliseconds: 100));

        // Background refresh should refetch all pages
        await infiniteQuery.sync();
        await Future.delayed(Duration(milliseconds: 30));

        expect(fetchCount, 4); // Should refetch both pages
        expect(infiniteQuery.data?.pages.length, 2);
      });

      test('should handle partial page failures gracefully', () async {
        int attemptCount = 0;

        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['test-partial-failure'],
          (pageParam) async {
            attemptCount++;
            await Future.delayed(Duration(milliseconds: 10));

            // Fail on second page, first attempt
            if (pageParam == 1 && attemptCount == 2) {
              throw Exception('Temporary page 1 failure');
            }

            return {
              'items': ['item${pageParam}_attempt${attemptCount}'],
              'hasMore': pageParam < 2,
              'page': pageParam,
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? lastPage.page + 1 : null,
            initialPageParam: 0,
          ),
        );

        // Fetch first page (should succeed)
        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 1);
        expect(attemptCount, 1);

        // Fetch second page (should fail)
        await infiniteQuery.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.error, isNotNull);
        expect(infiniteQuery.data?.pages.length, 1); // First page preserved

        // Retry should work
        await infiniteQuery.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.error, isNull);
        expect(infiniteQuery.data?.pages.length, 2);
      });

      test('should handle query invalidation correctly', () async {
        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['test-infinite-invalidation'],
          (pageParam) async {
            await Future.delayed(Duration(milliseconds: 10));
            return {
              'items': ['item${pageParam}'],
              'hasMore': pageParam < 1,
              'page': pageParam,
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? lastPage.page + 1 : null,
            initialPageParam: 0,
          ),
        );

        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        await infiniteQuery.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.isStale, false);
        expect(infiniteQuery.data?.pages.length, 2);

        // Invalidate query
        client.invalidateQueries(['test-infinite-invalidation']);

        expect(infiniteQuery.isStale, true);

        // Should refetch all pages on next access
        await infiniteQuery.sync();
        await Future.delayed(Duration(milliseconds: 30));

        expect(infiniteQuery.isStale, false);
        expect(infiniteQuery.data?.pages.length, 2);
      });

      test('should handle query removal correctly', () async {
        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['test-removal'],
          (pageParam) async {
            await Future.delayed(Duration(milliseconds: 10));
            return {
              'items': ['item${pageParam}_1', 'item${pageParam}_2'],
              'hasMore': pageParam < 1,
              'page': pageParam,
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? lastPage.page + 1 : null,
            initialPageParam: 0,
          ),
        );

        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        await infiniteQuery.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 2);

        // Remove query
        client.removeQueries(['test-removal']);

        // Should be removed from cache
        expect(client.getInfiniteQueryData<MockPage>(['test-removal']), isNull);
      });

      test('should handle concurrent page fetching safely', () async {
        int fetchCount = 0;

        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['test-concurrent-infinite'],
          (pageParam) async {
            fetchCount++;
            await Future.delayed(Duration(milliseconds: 30));
            return {
              'items': ['item${pageParam}_${fetchCount}'],
              'hasMore': pageParam < 3,
              'page': pageParam,
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? lastPage.page + 1 : null,
            initialPageParam: 0,
          ),
        );

        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 40));

        expect(fetchCount, 1);

        // Start multiple concurrent operations
        final futures = [
          infiniteQuery.fetchNextPage(),
          infiniteQuery.fetchNextPage(),
          infiniteQuery.refetch(),
        ];

        await Future.wait(futures);
        await Future.delayed(Duration(milliseconds: 40));

        // Should handle concurrency gracefully without duplicate fetches
        expect(infiniteQuery.data?.pages.length, greaterThanOrEqualTo(1));
        expect(fetchCount,
            lessThanOrEqualTo(4)); // Should not exceed reasonable limit
      });

      test('should handle memory cleanup on disposal', () async {
        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, int>(
          ['test-memory-cleanup'],
          (pageParam) async => {
            'items': ['item${pageParam}'],
            'hasMore': false,
            'page': pageParam,
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) => null,
            initialPageParam: 0,
          ),
        );

        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data, isNotNull);

        // Dispose the query
        infiniteQuery.dispose();

        // Data should be cleaned up
        expect(
          client.getInfiniteQueryData<MockPage>(['test-memory-cleanup']),
          isNull,
        );
      });

      test('should handle edge case page parameters', () async {
        final infiniteQuery =
            client.useInfiniteQuery<MockPage, Map<String, dynamic>, String?>(
          ['test-edge-cases'],
          (pageParam) async {
            await Future.delayed(Duration(milliseconds: 10));
            return {
              'items': ['item_${pageParam ?? "null"}'],
              'hasMore': pageParam == null,
              'page': 0,
            };
          },
          options: InfiniteQueryOptions(
            transformer: (json) => MockPage.fromJson(json),
            getNextPageParam: (lastPage, allPages) =>
                lastPage.hasMore ? 'second_page' : null,
            initialPageParam: null, // Start with null
          ),
        );

        await infiniteQuery.waitForHydration();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 1);
        expect(infiniteQuery.data?.pages.first.items.first, 'item_null');

        // Fetch next page with non-null param
        await infiniteQuery.fetchNextPage();
        await Future.delayed(Duration(milliseconds: 20));

        expect(infiniteQuery.data?.pages.length, 2);
        expect(infiniteQuery.data?.pages.last.items.first, 'item_second_page');
      });
    });
  });
}
