import 'dart:convert';
import 'package:query_signals/p_signals/client/p_signals_client.dart';
import 'package:query_signals/p_signals/models/storable.model.dart';
import 'package:query_signals/storage/base_persisted_storage.abstract.dart';
import 'package:query_signals/query_signals/models/infinite_query_data.model.dart';
import 'package:query_signals/query_signals/models/infinite_query_options.model.dart';
import 'package:query_signals/query_signals/models/query_client_config.model.dart';
import 'package:query_signals/query_signals/models/query_key.model.dart';
import 'package:query_signals/query_signals/models/query_mutation_options.model.dart';
import 'package:query_signals/query_signals/models/query_options.model.dart';
import '../query.dart';
import '../mutation.dart';
import '../infinite_query.dart';
import '../types/query.type.dart';

/// Central manager for all queries and mutations - similar to React Query's QueryClient
/// Handles caching, invalidation, and query lifecycle
///
/// **SINGLETON PATTERN** - Always returns the same instance across your entire app
/// This ensures:
/// - Consistent cache across all widgets/stores
/// - No duplicate initialization
/// - Shared query states
///
/// Usage:
/// ```dart
/// // Initialize once in main() with your defaults
/// await QueryClient().init(QueryClientConfig(
///   defaultStaleDuration: Duration(minutes: 10),
///   // defaultCacheDuration: Duration(hours: 2), // Uncomment to override infinite default
/// ));
///
/// // Use anywhere without specifying durations
/// final posts = client.useQuery(['posts'], fetchPosts);
/// ```
class QueryClient {
  static final QueryClient _instance = QueryClient._internal();
  factory QueryClient() => _instance;
  QueryClient._internal();

  /// Global configuration with defaults
  QueryClientConfig _config = const QueryClientConfig();

  // Internal storage for active queries and mutations
  final Map<QueryKey, Query> _queries = {};
  final Map<QueryKey, InfiniteQuery> _infiniteQueries = {};
  final Map<String, Mutation> _mutations = {};
  late final BasePersistedStorage _storage;

  bool _initialized = false;
  int _mutationKeyCounter = 0; // For generating unique mutation keys

  /// Access to current configuration
  QueryClientConfig get config => _config;

  /// Initialize the client with your persist_signals storage and optional configuration
  /// Call this once in your app initialization
  ///
  /// Example:
  /// ```dart
  /// await QueryClient().init(QueryClientConfig(
  ///   defaultStaleDuration: Duration(minutes: 10),
  ///   // defaultCacheDuration: Duration(hours: 2), // Uncomment to override infinite default
  /// ));
  /// ```
  Future<void> init({
    QueryClientConfig? config,
    required BasePersistedStorage storage,
  }) async {
    if (_initialized) return;

    if (config != null) {
      _config = config;
    }

    _storage = storage;
    PSignalsClient.init(storage);
    _initialized = true;
  }

  // ==================== QUERY CREATION ====================

  /// Create or get existing query - uses global defaults if options are not specified
  ///
  /// Example with transformer (React Query style):
  /// ```dart
  /// final postsQuery = client.useQuery<List<Post>, List<dynamic>>(
  ///   ['posts'],
  ///   () => api.get('/posts'), // Raw API call
  ///   options: QueryOptions(
  ///     transformer: (jsonList) => jsonList.map((json) => Post.fromJson(json)).toList()
  ///   )
  /// );
  /// ```
  Query<TData, TQueryFnData>
      useQuery<TData extends Object?, TQueryFnData extends Object?>(
    List<dynamic> key,
    QueryFn<TQueryFnData> queryFn, {
    QueryOptions<TData, TQueryFnData>? options,
  }) {
    // Ensure client is initialized
    if (!_initialized) {
      throw Exception('QueryClient not initialized');
    }

    final queryKey = QueryKey(key);

    // Return existing query if already created
    if (_queries.containsKey(queryKey)) {
      final existingQuery = _queries[queryKey] as Query<TData, TQueryFnData>;

      // Mark as reused since we're returning an existing query
      existingQuery.isReused = true;

      // Handle refetchOnMount for existing queries
      final shouldRefetchOnMount = options?.refetchOnMount ?? true;

      if (shouldRefetchOnMount && existingQuery.isStale) {
        // Trigger smart sync if stale (background refresh for stale, loading for expired)
        Future.microtask(() => existingQuery.sync());
      }

      return existingQuery;
    }

    // Apply global defaults if not specified in options
    final finalOptions = options ?? QueryOptions<TData, TQueryFnData>();
    final effectiveOptions = QueryOptions<TData, TQueryFnData>(
      staleDuration: finalOptions.staleDuration ?? _config.defaultStaleDuration,
      cacheDuration: finalOptions.cacheDuration ?? _config.defaultCacheDuration,
      transformer: finalOptions.transformer,
      enabled: finalOptions.enabled,
      refetchOnMount: finalOptions.refetchOnMount,
      granularUpdates: finalOptions.granularUpdates,
      requestTimeout: finalOptions.requestTimeout,
      refetchInterval: finalOptions.refetchInterval,
      refetchIntervalFn: finalOptions.refetchIntervalFn,
      watchSignals: finalOptions.watchSignals,
      refetchOnSignalChange: finalOptions.refetchOnSignalChange,
    );

    // Create new query with transformer support
    final query = Query<TData, TQueryFnData>(
      queryKey: queryKey,
      queryFn: queryFn,
      options: effectiveOptions,
      client: this,
    );

    _queries[queryKey] = query;
    return query;
  }

  /// Create or get existing infinite query for paginated data
  ///
  /// Example:
  /// ```dart
  /// final postsQuery = client.useInfiniteQuery<PostsPage, Map<String, dynamic>, int>(
  ///   ['posts'],
  ///   (pageParam) => api.get('/posts?skip=${pageParam * 20}&limit=20'),
  ///   options: InfiniteQueryOptions(
  ///     transformer: (json) => PostsPage.fromJson(json),
  ///     getNextPageParam: (lastPage, allPages) =>
  ///       lastPage.posts.length == 20 ? allPages.length : null,
  ///     initialPageParam: 0,
  ///   ),
  /// );
  /// ```
  InfiniteQuery<TData, TQueryFnData, TPageParam> useInfiniteQuery<
      TData extends Object?,
      TQueryFnData extends Object?,
      TPageParam extends Object?>(
    List<dynamic> key,
    Future<TQueryFnData> Function(TPageParam pageParam) queryFn, {
    InfiniteQueryOptions<TData, TQueryFnData, TPageParam>? options,
  }) {
    // Ensure client is initialized
    if (!_initialized) {
      throw Exception('QueryClient not initialized');
    }

    final queryKey = QueryKey(key);

    // Return existing infinite query if already created
    if (_infiniteQueries.containsKey(queryKey)) {
      final existingQuery = _infiniteQueries[queryKey]
          as InfiniteQuery<TData, TQueryFnData, TPageParam>;

      // Mark as reused since we're returning an existing infinite query
      existingQuery.isReused = true;

      // Handle refetchOnMount for existing queries
      final shouldRefetchOnMount = options?.refetchOnMount ?? true;

      if (shouldRefetchOnMount && existingQuery.isStale) {
        // Trigger smart sync if stale
        Future.microtask(() => existingQuery.sync());
      }

      return existingQuery;
    }

    // Apply global defaults if not specified in options
    final finalOptions =
        options ?? InfiniteQueryOptions<TData, TQueryFnData, TPageParam>();
    final effectiveOptions =
        InfiniteQueryOptions<TData, TQueryFnData, TPageParam>(
      staleDuration: finalOptions.staleDuration ?? _config.defaultStaleDuration,
      cacheDuration: finalOptions.cacheDuration ?? _config.defaultCacheDuration,
      transformer: finalOptions.transformer,
      enabled: finalOptions.enabled,
      refetchOnMount: finalOptions.refetchOnMount,
      getNextPageParam: finalOptions.getNextPageParam,
      getPreviousPageParam: finalOptions.getPreviousPageParam,
      initialPageParam: finalOptions.initialPageParam,
      requestTimeout: finalOptions.requestTimeout,
    );

    // Create new infinite query
    final infiniteQuery = InfiniteQuery<TData, TQueryFnData, TPageParam>(
      queryKey: queryKey,
      queryFn: queryFn,
      options: effectiveOptions,
      client: this,
    );

    _infiniteQueries[queryKey] = infiniteQuery;
    return infiniteQuery;
  }

  // ==================== MUTATION CREATION ====================

  /// Create a mutation for data modifications (create/update/delete)
  ///
  /// Example:
  /// ```dart
  /// final updateMutation = client.useMutation<Post, Map<String, dynamic>>(
  ///   (data) => api.patch('/posts/${data['id']}', data),
  ///   onSuccess: (updatedPost) => client.invalidateQueries(['posts'])
  /// );
  /// ```
  Mutation<TData, TVariables>
      useMutation<TData extends Object?, TVariables extends Object?>(
    Future<TData> Function(TVariables variables) mutationFn, {
    MutationOptions? options,
  }) {
    if (!_initialized) {
      throw Exception('QueryClient not initialized');
    }

    // Generate unique key for this mutation
    final mutationKey =
        'mutation_${_mutationKeyCounter++}_${DateTime.now().millisecondsSinceEpoch}';

    final mutation = Mutation<TData, TVariables>(
      mutationKey: mutationKey,
      mutationFn: mutationFn,
      options: options ?? const MutationOptions(),
      client: this,
    );

    _mutations[mutationKey] = mutation;
    return mutation;
  }

  /// Dispose a specific mutation and clean up its signals (called by Mutation.dispose())
  void disposeMutation(String mutationKey) {
    _mutations.remove(mutationKey);
  }

  // ==================== CACHE MANAGEMENT ====================
  // These methods handle the persistent storage layer

  /// Get cached data for a query key - returns raw data for transformation
  Future<T?> getCachedData<T>(
    QueryKey key, {
    bool granularUpdates = false,
  }) async {
    try {
      final storeKey = 'query_data_${key.toString()}';

      // Use record storage for granular updates
      if (granularUpdates) {
        final records = await _storage.getRecords(storeKey);
        if (records.isNotEmpty) {
          return records as T?;
        }
      }

      // Default: JSON storage with optimized primitive handling
      final cached = await _storage.get(storeKey);
      if (cached == null) return null;

      // For primitive types, return directly
      if (T == String) return cached as T?;
      if (T == int) return int.tryParse(cached) as T?;
      if (T == double) return double.tryParse(cached) as T?;
      if (T == bool) return (cached == 'true') as T?;

      // For complex types, decode JSON
      final decoded = jsonDecode(cached);

      // If T is dynamic, return raw decoded data for transformation later
      if (T == dynamic) return decoded as T;

      // Otherwise cast to specific type (for optimistic updates)
      return decoded as T?;
    } catch (e) {
      return null;
    }
  }

  /// Store data in cache
  Future<void> setCachedData<T>(
    QueryKey key,
    T data, {
    bool granularUpdates = false,
  }) async {
    try {
      final storeKey = 'query_data_${key.toString()}';

      // Use efficient record storage if granular updates enabled
      if (granularUpdates && data is List && data.isNotEmpty) {
        final firstItem = (data as List).first;
        if (firstItem is StorableWithId) {
          final records = (data as List<StorableWithId>)
              .map(
                (item) => {
                  'id': item.id,
                  ...(item as dynamic).toJson() as Map<String, dynamic>,
                },
              )
              .toList();
          await _storage.setRecords(storeKey, records);
          return;
        }
      }

      // Optimized storage for primitive types
      if (data is String || data is int || data is double || data is bool) {
        await _storage.set(storeKey, data.toString());
        return;
      }

      // Default: JSON storage for complex types
      final encoded = jsonEncode(data);
      await _storage.set(storeKey, encoded);
    } catch (e) {
      print('Error setting cached data: $e');
      // Silent fail - cache is not critical
    }
  }

  /// Get when data was last cached
  Future<DateTime?> getCachedTime(QueryKey key) async {
    try {
      final cached = await _storage.get('query_time_${key.toString()}');
      if (cached == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(int.parse(cached));
    } catch (e) {
      return null;
    }
  }

  /// Store cache timestamp
  Future<void> setCachedTime(QueryKey key, DateTime time) async {
    try {
      await _storage.set(
        'query_time_${key.toString()}',
        time.millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      print('Error setting cached time: $e');
      // Silent fail
    }
  }

  // ==================== QUERY INVALIDATION ====================

  /// Mark queries as stale and refetch them (like React Query's invalidateQueries)
  ///
  /// Examples:
  /// - `invalidateQueries(['posts'])` - invalidates all post queries
  /// - `invalidateQueries(null)` - invalidates ALL queries
  void invalidateQueries(List<dynamic>? keyPattern) {
    if (keyPattern == null) {
      // Invalidate all queries and infinite queries
      for (final query in _queries.values) {
        query.invalidate();
      }
      for (final infiniteQuery in _infiniteQueries.values) {
        infiniteQuery.invalidate();
      }
      return;
    }

    // Invalidate matching queries (prefix matching)
    final pattern = QueryKey(keyPattern);
    for (final entry in _queries.entries) {
      if (_keysMatch(entry.key, pattern)) {
        entry.value.invalidate();
      }
    }
    for (final entry in _infiniteQueries.entries) {
      if (_keysMatch(entry.key, pattern)) {
        entry.value.invalidate();
      }
    }
  }

  /// Remove queries from memory
  /// // TODO: remove cache too?
  void removeQueries(List<dynamic>? keyPattern) {
    if (keyPattern == null) {
      _queries.clear();
      _infiniteQueries.clear();
      return;
    }

    final pattern = QueryKey(keyPattern);
    _queries.removeWhere((key, _) => _keysMatch(key, pattern));
    _infiniteQueries.removeWhere((key, _) => _keysMatch(key, pattern));
  }

  /// Internal method to remove a single query
  void removeQuery(QueryKey key) {
    _queries.remove(key);
  }

  /// Check if a query key matches a pattern (prefix matching)
  bool _keysMatch(QueryKey key1, QueryKey key2) {
    if (key2.key.isEmpty) return true; // Empty pattern matches all
    if (key1.key.length < key2.key.length) return false;

    for (int i = 0; i < key2.key.length; i++) {
      if (key1.key[i] != key2.key[i]) return false;
    }
    return true;
  }

  // ==================== OPTIMISTIC UPDATES ====================

  /// Manually set query data (for optimistic updates)
  /// Use this to immediately update UI before server confirms
  void setQueryData<T>(List<dynamic> key, T data) {
    final queryKey = QueryKey(key);
    final query = _queries[queryKey] as Query<T, dynamic>?;
    query?.setData(data);
  }

  /// Get current query data
  T? getQueryData<T>(List<dynamic> key) {
    final queryKey = QueryKey(key);
    final query = _queries[queryKey] as Query<T, dynamic>?;
    return query?.data;
  }

  /// Check if a query exists (for ownership tracking in mixins)
  bool hasQuery(List<dynamic> key) {
    final queryKey = QueryKey(key);
    return _queries.containsKey(queryKey);
  }

  /// Check if an infinite query exists (for ownership tracking in mixins)
  bool hasInfiniteQuery(List<dynamic> key) {
    final queryKey = QueryKey(key);
    return _infiniteQueries.containsKey(queryKey);
  }

  /// Get current infinite query data
  InfiniteData<T>? getInfiniteQueryData<T>(List<dynamic> key) {
    final queryKey = QueryKey(key);
    final infiniteQuery = _infiniteQueries[queryKey];
    if (infiniteQuery != null) {
      // Use dynamic casting since we can't know the exact generic types
      return (infiniteQuery as dynamic).data as InfiniteData<T>?;
    }
    return null;
  }

  /// Manually set infinite query data (for optimistic updates)
  void setInfiniteQueryData<T>(List<dynamic> key, InfiniteData<T> data) {
    final queryKey = QueryKey(key);
    final infiniteQuery = _infiniteQueries[queryKey];
    if (infiniteQuery != null) {
      // Use dynamic casting since we can't know the exact generic types
      (infiniteQuery as dynamic).setData(data);
    }
  }

  /// Update an item across all pages of an infinite query
  /// Useful for optimistic updates when you don't know which page contains the item
  void updateInfiniteQueryItem<TPage, TItem>(
    List<dynamic> key,
    TItem updatedItem,
    String Function(TItem) getId,
    List<TItem> Function(TPage page) getItems,
    TPage Function(TPage page, List<TItem> newItems) updatePage,
  ) {
    final infiniteData = getInfiniteQueryData<TPage>(key);
    if (infiniteData == null) return;

    final updatedItemId = getId(updatedItem);
    bool found = false;

    final updatedPages = infiniteData.pages.map((page) {
      final items = getItems(page);
      final itemIndex = items.indexWhere(
        (item) => getId(item) == updatedItemId,
      );

      if (itemIndex >= 0) {
        found = true;
        final newItems = [...items];
        newItems[itemIndex] = updatedItem;
        return updatePage(page, newItems);
      }

      return page;
    }).toList();

    if (found) {
      final newInfiniteData = InfiniteData<TPage>(
        pages: updatedPages,
        pageParams: infiniteData.pageParams,
      );
      setInfiniteQueryData(key, newInfiniteData);
    }
  }

  /// Add an item to the first page of an infinite query
  /// Useful for optimistic updates when creating new items
  void addToInfiniteQueryFirstPage<TPage, TItem>(
    List<dynamic> key,
    TItem newItem,
    List<TItem> Function(TPage page) getItems,
    TPage Function(TPage page, List<TItem> newItems) updatePage,
  ) {
    final infiniteData = getInfiniteQueryData<TPage>(key);
    if (infiniteData == null || infiniteData.pages.isEmpty) return;

    final firstPage = infiniteData.pages.first;
    final items = getItems(firstPage);
    final newItems = [newItem, ...items];
    final updatedFirstPage = updatePage(firstPage, newItems);

    final updatedPages = [updatedFirstPage, ...infiniteData.pages.skip(1)];

    final newInfiniteData = InfiniteData<TPage>(
      pages: updatedPages,
      pageParams: infiniteData.pageParams,
    );
    setInfiniteQueryData(key, newInfiniteData);
  }

  /// Remove an item from all pages of an infinite query
  void removeFromInfiniteQuery<TPage, TItem>(
    List<dynamic> key,
    String itemId,
    String Function(TItem) getId,
    List<TItem> Function(TPage page) getItems,
    TPage Function(TPage page, List<TItem> newItems) updatePage,
  ) {
    final infiniteData = getInfiniteQueryData<TPage>(key);
    if (infiniteData == null) return;

    bool found = false;

    final updatedPages = infiniteData.pages.map((page) {
      final items = getItems(page);
      final itemExists = items.any((item) => getId(item) == itemId);

      if (itemExists) {
        found = true;
        final newItems = items.where((item) => getId(item) != itemId).toList();
        return updatePage(page, newItems);
      }

      return page;
    }).toList();

    if (found) {
      final newInfiniteData = InfiniteData<TPage>(
        pages: updatedPages,
        pageParams: infiniteData.pageParams,
      );
      setInfiniteQueryData(key, newInfiniteData);
    }
  }

  /// Update a single item in a list query (only works with granularUpdates: true)
  /// Perfect for mutations - updates only the changed item, not entire list
  ///
  /// Example:
  /// ```dart
  /// // Update post with id=5 in the posts list
  /// client.updateQueryListItem<List<Post>, Post>(
  ///   ['posts'],
  ///   updatedPost,
  ///   itemId: (post) => post.id.toString()
  /// );
  /// ```
  void updateQueryListItem<TList extends List<TItem>, TItem>(
    List<dynamic> key,
    TItem updatedItem, {
    required String Function(TItem) itemId,
  }) {
    final queryKey = QueryKey(key);
    final query = _queries[queryKey];

    // Only works with granular updates enabled
    if (query?.options.granularUpdates != true) {
      throw Exception(
        'updateQueryListItem requires granularUpdates: true in QueryOptions',
      );
    }

    final currentData = getQueryData<TList>(key);
    if (currentData == null) return;

    final list = List<TItem>.from(currentData);
    final targetId = itemId(updatedItem);
    final index = list.indexWhere((item) => itemId(item) == targetId);

    if (index >= 0) {
      list[index] = updatedItem;
      setQueryData(key, list as TList);

      // Also update storage efficiently (single record)
      if (updatedItem is StorableWithId) {
        final storeKey = 'query_data_${queryKey.toString()}';
        final data = (updatedItem as dynamic).toJson() as Map<String, dynamic>;
        _storage.setRecord(storeKey, (updatedItem as StorableWithId).id, data);
      }
    }
  }

  /// Add item to a list query (only works with granularUpdates: true)
  void addQueryListItem<TList extends List<TItem>, TItem>(
    List<dynamic> key,
    TItem newItem,
  ) {
    final queryKey = QueryKey(key);
    final query = _queries[queryKey];

    if (query?.options.granularUpdates != true) {
      throw Exception(
        'addQueryListItem requires granularUpdates: true in QueryOptions',
      );
    }

    final currentData = getQueryData<TList>(key);
    final list =
        currentData != null ? List<TItem>.from(currentData) : <TItem>[];

    list.add(newItem);
    setQueryData(key, list as TList);

    // Also update storage efficiently (single record)
    if (newItem is StorableWithId) {
      final storeKey = 'query_data_${queryKey.toString()}';
      final data = (newItem as dynamic).toJson() as Map<String, dynamic>;
      _storage.setRecord(storeKey, (newItem as StorableWithId).id, data);
    }
  }

  /// Remove item from a list query (only works with granularUpdates: true)
  void removeQueryListItem<TList extends List<TItem>, TItem>(
    List<dynamic> key,
    String itemId,
    String Function(TItem) getId,
  ) {
    final queryKey = QueryKey(key);
    final query = _queries[queryKey];

    if (query?.options.granularUpdates != true) {
      throw Exception(
        'removeQueryListItem requires granularUpdates: true in QueryOptions',
      );
    }

    final currentData = getQueryData<TList>(key);
    if (currentData == null) return;

    final list = List<TItem>.from(currentData);
    list.removeWhere((item) => getId(item) == itemId);
    setQueryData(key, list as TList);

    // Also remove from storage efficiently (single record)
    final storeKey = 'query_data_${queryKey.toString()}';
    _storage.deleteRecord(storeKey, itemId);
  }

  // ==================== PREFETCHING ====================

  /// Prefetch data before it's needed (great for predictive loading)
  Future<void>
      prefetchQuery<TData extends Object?, TQueryFnData extends Object?>(
    List<dynamic> key,
    QueryFn<TQueryFnData> queryFn, {
    QueryOptions<TData, TQueryFnData>? options,
  }) async {
    final query = useQuery(key, queryFn, options: options);
    await query.refetch();
  }

  /// Prefetch infinite query data before it's needed
  Future<void> prefetchInfiniteQuery<TData extends Object?,
      TQueryFnData extends Object?, TPageParam extends Object?>(
    List<dynamic> key,
    Future<TQueryFnData> Function(TPageParam pageParam) queryFn, {
    InfiniteQueryOptions<TData, TQueryFnData, TPageParam>? options,
  }) async {
    final infiniteQuery = useInfiniteQuery(key, queryFn, options: options);
    await infiniteQuery.refetch();
  }

  /// Wait for all active queries to complete hydration (load cached data)
  /// Perfect for calling in main() to avoid loading flicker on app start
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   await QueryClient().init();
  ///
  ///   // Create your stores (this creates the queries)
  ///   final postStore = PostStore();
  ///
  ///   // Wait for all cached data to load
  ///   await QueryClient().waitForHydration();
  ///
  ///   runApp(MyApp());
  /// }
  /// ```
  Future<void> waitForHydration() async {
    final queryFutures =
        _queries.values.map((query) => query.waitForHydration()).toList();

    final infiniteQueryFutures = _infiniteQueries.values
        .map((infiniteQuery) => infiniteQuery.waitForHydration())
        .toList();

    final allFutures = [...queryFutures, ...infiniteQueryFutures];

    if (allFutures.isNotEmpty) {
      await Future.wait(allFutures);
    }
  }

  /// Wait for specific queries to hydrate
  ///
  /// Example:
  /// ```dart
  /// await client.waitForQueriesHydration([
  ///   ['posts'],
  ///   ['user', userId],
  /// ]);
  /// ```
  Future<void> waitForQueriesHydration(List<List<dynamic>> queryKeys) async {
    final queryFutures = queryKeys
        .map((key) => _queries[QueryKey(key)]?.waitForHydration())
        .where((future) => future != null)
        .cast<Future<void>>()
        .toList();

    final infiniteQueryFutures = queryKeys
        .map((key) => _infiniteQueries[QueryKey(key)]?.waitForHydration())
        .where((future) => future != null)
        .cast<Future<void>>()
        .toList();

    final allFutures = [...queryFutures, ...infiniteQueryFutures];

    if (allFutures.isNotEmpty) {
      await Future.wait(allFutures);
    }
  }

  /// Dispose a specific query and clean up its signals
  void disposeQuery(List<dynamic> key) {
    final queryKey = QueryKey(key);
    final query = _queries[queryKey];
    final infiniteQuery = _infiniteQueries[queryKey];

    query?.dispose();
    infiniteQuery?.dispose();

    _queries.remove(queryKey);
    _infiniteQueries.remove(queryKey);
  }

  /// Dispose all queries and mutations (call this when app shuts down)
  void disposeAll() {
    // Create copies to avoid concurrent modification
    final queriesToDispose = List.from(_queries.values);
    final infiniteQueriesToDispose = List.from(_infiniteQueries.values);
    final mutationsToDispose = List.from(_mutations.values);

    // Clear maps first
    _queries.clear();
    _infiniteQueries.clear();
    _mutations.clear();

    // Then dispose (queries and mutations will try to remove themselves)
    for (final query in queriesToDispose) {
      query.dispose();
    }

    for (final infiniteQuery in infiniteQueriesToDispose) {
      infiniteQuery.dispose();
    }

    for (final mutation in mutationsToDispose) {
      mutation.dispose();
    }
  }
}
