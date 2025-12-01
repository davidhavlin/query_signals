import 'dart:async';
import 'package:query_signals/query_signals/models/infinite_query_data.model.dart';
import 'package:query_signals/query_signals/models/infinite_query_options.model.dart';
import 'package:query_signals/query_signals/models/query_error.model.dart';
import 'package:query_signals/query_signals/models/query_key.model.dart';
import 'package:signals/signals_flutter.dart';
import 'enums/query_status.enum.dart';
import 'client/query_client.dart';

/// A reactive infinite query that handles paginated data fetching
/// Similar to React Query's useInfiniteQuery
///
/// Example usage:
/// ```dart
/// final postsQuery = client.useInfiniteQuery<PostsPage, Map<String, dynamic>, int>(
///   ['posts'],
///   (pageParam) => api.get('/posts?page=$pageParam'),
///   options: InfiniteQueryOptions(
///     transformer: (json) => PostsPage.fromJson(json),
///     getNextPageParam: (lastPage, allPages) =>
///       lastPage.hasMore ? allPages.length + 1 : null,
///   ),
/// );
///
/// // In your widget
/// Watch((context) {
///   final allPosts = postsQuery.data?.flatMap((page) => page.posts) ?? [];
///   return ListView.builder(
///     itemCount: allPosts.length + (postsQuery.hasNextPage ? 1 : 0),
///     itemBuilder: (context, index) {
///       if (index < allPosts.length) {
///         return PostCard(post: allPosts[index]);
///       }
///       // Load more trigger
///       postsQuery.fetchNextPage();
///       return LoadingIndicator();
///     },
///   );
/// })
/// ```
class InfiniteQuery<TData extends Object?, TQueryFnData extends Object?,
    TPageParam extends Object?> {
  final QueryKey queryKey;
  final Future<TQueryFnData> Function(TPageParam pageParam) queryFn;
  final InfiniteQueryOptions<TData, TQueryFnData, TPageParam> options;
  final QueryClient _client;

  /// Whether this infinite query was reused from cache (not newly created)
  /// Used by mixins to decide whether to dispose it
  bool isReused = false;

  /// Whether this infinite query has been disposed - prevents signal updates after disposal
  bool _isDisposed = false;

  // Internal signals for reactivity
  late final Signal<QueryStatus> _status;
  late final Signal<InfiniteData<TData>?> _data;
  late final Signal<QueryError?> _error;
  late final Signal<DateTime?> _lastFetched;
  late final Signal<bool> _isStale;
  late final Signal<bool> _isFetchingNextPage;
  late final Signal<bool> _isFetchingPreviousPage;

  // Computed signals for convenience
  late final FlutterComputed<bool> _isLoadingSignal;
  late final FlutterComputed<bool> _isSuccessSignal;
  late final FlutterComputed<bool> _isErrorSignal;
  late final FlutterComputed<bool> _hasNextPageSignal;
  late final FlutterComputed<bool> _hasPreviousPageSignal;

  // Hydration and request deduplication
  bool isHydrated = false;
  final Completer<void> _hydrationCompleter = Completer<void>();
  Future<void>? _currentFetch;

  InfiniteQuery({
    required this.queryKey,
    required this.queryFn,
    required this.options,
    required QueryClient client,
  }) : _client = client {
    // Initialize signals
    _status = signal(QueryStatus.idle);
    _data = signal<InfiniteData<TData>?>(null);
    _error = signal<QueryError?>(null);
    _lastFetched = signal<DateTime?>(null);
    _isStale = signal(true);
    _isFetchingNextPage = signal(false);
    _isFetchingPreviousPage = signal(false);

    // Initialize computed signals
    _isLoadingSignal = computed(() => _status.value == QueryStatus.loading);
    _isSuccessSignal = computed(() => _status.value == QueryStatus.success);
    _isErrorSignal = computed(() => _status.value == QueryStatus.error);

    _hasNextPageSignal = computed(() {
      final data = _data.value;
      if (data == null || data.pages.isEmpty)
        return true; // Can fetch first page

      if (options.getNextPageParam == null) return false;

      final nextPageParam = options.getNextPageParam!(
        data.pages.last,
        data.pages,
      );
      return nextPageParam != null;
    });

    _hasPreviousPageSignal = computed(() {
      final data = _data.value;
      if (data == null || data.pages.isEmpty) return false;

      if (options.getPreviousPageParam == null) return false;

      final prevPageParam = options.getPreviousPageParam!(
        data.pages.first,
        data.pages,
      );
      return prevPageParam != null;
    });

    // Auto-fetch if enabled
    if (options.enabled) {
      _initQuery();
    }
  }

  // ==================== REACTIVE GETTERS ====================

  /// Current status of the query
  QueryStatus get status => _status.value;

  /// All pages data
  InfiniteData<TData>? get data => _data.value;

  /// Error object if query failed
  QueryError? get error => _error.value;

  /// Convenient boolean flags
  bool get isLoading => _status.value == QueryStatus.loading;
  bool get isSuccess => _status.value == QueryStatus.success;
  bool get isError => _status.value == QueryStatus.error;
  bool get isIdle => _status.value == QueryStatus.idle;

  /// Pagination state
  bool get isFetchingNextPage => _isFetchingNextPage.value;
  bool get isFetchingPreviousPage => _isFetchingPreviousPage.value;
  bool get hasNextPage => _hasNextPageSignal.value;
  bool get hasPreviousPage => _hasPreviousPageSignal.value;

  /// Whether data is stale and should be refetched
  bool get isStale {
    if (_isStale.value) return true;

    final lastFetch = _lastFetched.value;
    if (lastFetch == null) return false;

    final staleDuration =
        options.staleDuration ?? _client.config.defaultStaleDuration;
    return DateTime.now().difference(lastFetch) > staleDuration;
  }

  /// When data was last successfully fetched
  DateTime? get lastFetched => _lastFetched.value;

  /// Wait for cached data to load
  Future<void> waitForHydration() => _hydrationCompleter.future;

  // ==================== SIGNAL GETTERS ====================

  Signal<QueryStatus> get statusSignal => _status;
  Signal<InfiniteData<TData>?> get dataSignal => _data;
  Signal<QueryError?> get errorSignal => _error;
  FlutterComputed<bool> get isLoadingSignal => _isLoadingSignal;
  FlutterComputed<bool> get isSuccessSignal => _isSuccessSignal;
  FlutterComputed<bool> get isErrorSignal => _isErrorSignal;
  FlutterComputed<bool> get hasNextPageSignal => _hasNextPageSignal;
  FlutterComputed<bool> get hasPreviousPageSignal => _hasPreviousPageSignal;

  // ==================== QUERY LIFECYCLE ====================

  /// Initialize query - load cache first, then fetch if needed
  Future<void> _initQuery() async {
    try {
      final cachedData = await _loadCachedData();

      if (cachedData != null) {
        if (!_isDisposed) {
          _data.value = cachedData;
          _status.value = QueryStatus.success;
        }
        _lastFetched.value = await _client.getCachedTime(queryKey);
        _isStale.value = false;
      }

      _completeHydration();

      // Fetch first page if no cache or stale
      if (cachedData == null || isStale) {
        await _fetchFirstPage();
      }
    } catch (e) {
      _completeHydration();
    }
  }

  /// Load cached infinite data
  Future<InfiniteData<TData>?> _loadCachedData() async {
    final rawCached = await _client.getCachedData<Map<String, dynamic>>(
      queryKey,
    );
    if (rawCached == null) return null;

    try {
      if (options.transformer != null) {
        final pages = (rawCached['pages'] as List)
            .map((pageData) => options.transformer!(pageData as TQueryFnData))
            .toList();

        return InfiniteData<TData>(
          pages: pages,
          pageParams: rawCached['pageParams'] as List,
        );
      }

      return InfiniteData.fromJson<TData>(
        rawCached,
        (pageData) => pageData as TData,
      );
    } catch (e) {
      print('Failed to load cached infinite data: $e');
      return null;
    }
  }

  /// Fetch the first page
  Future<void> _fetchFirstPage() async {
    if (_currentFetch != null) return _currentFetch;

    _currentFetch = _performFirstPageFetch();
    await _currentFetch;
    _currentFetch = null;
  }

  Future<void> _performFirstPageFetch() async {
    if (!_isDisposed) _status.value = QueryStatus.loading;
    _error.value = null;

    try {
      final initialPageParam = options.initialPageParam;
      final pageData = await queryFn(initialPageParam as TPageParam);
      final transformedPage =
          options.transformer?.call(pageData) ?? pageData as TData;

      final infiniteData = InfiniteData<TData>(
        pages: [transformedPage],
        pageParams: [initialPageParam],
      );

      if (!_isDisposed) {
        _data.value = infiniteData;
        _status.value = QueryStatus.success;
      }
      _lastFetched.value = DateTime.now();
      _isStale.value = false;

      // Cache the data
      await _client.setCachedData(queryKey, infiniteData.toJson());
      await _client.setCachedTime(queryKey, DateTime.now());
    } catch (e) {
      final error = _createQueryError(e);
      _error.value = error;
      if (!_isDisposed) _status.value = QueryStatus.error;
      print('Query error: $error');
    }
  }

  /// Fetch the next page
  Future<void> fetchNextPage() async {
    if (!hasNextPage || _isFetchingNextPage.value) return;

    _isFetchingNextPage.value = true;

    try {
      final currentData = _data.value;
      if (currentData == null || options.getNextPageParam == null) return;

      final nextPageParam = options.getNextPageParam!(
        currentData.pages.last,
        currentData.pages,
      );

      if (nextPageParam == null) return;

      final pageData = await queryFn(nextPageParam);
      final transformedPage =
          options.transformer?.call(pageData) ?? pageData as TData;

      final newData = currentData.addPage(transformedPage, nextPageParam);
      _data.value = newData;
      _lastFetched.value = DateTime.now();

      // Update cache
      await _client.setCachedData(queryKey, newData.toJson());
      await _client.setCachedTime(queryKey, DateTime.now());
    } catch (e) {
      final error = _createQueryError(e);
      _error.value = error;
      print('Fetch next page error: $error');
    } finally {
      _isFetchingNextPage.value = false;
    }
  }

  /// Fetch the previous page (for bidirectional pagination)
  Future<void> fetchPreviousPage() async {
    if (!hasPreviousPage || _isFetchingPreviousPage.value) return;

    _isFetchingPreviousPage.value = true;

    try {
      final currentData = _data.value;
      if (currentData == null || options.getPreviousPageParam == null) return;

      final prevPageParam = options.getPreviousPageParam!(
        currentData.pages.first,
        currentData.pages,
      );

      if (prevPageParam == null) return;

      final pageData = await queryFn(prevPageParam);
      final transformedPage =
          options.transformer?.call(pageData) ?? pageData as TData;

      // Add to beginning
      final newData = InfiniteData<TData>(
        pages: [transformedPage, ...currentData.pages],
        pageParams: [prevPageParam, ...currentData.pageParams],
      );

      _data.value = newData;
      _lastFetched.value = DateTime.now();

      // Update cache
      await _client.setCachedData(queryKey, newData.toJson());
      await _client.setCachedTime(queryKey, DateTime.now());
    } catch (e) {
      final error = _createQueryError(e);
      _error.value = error;
      print('Fetch previous page error: $error');
    } finally {
      _isFetchingPreviousPage.value = false;
    }
  }

  /// Refetch all pages
  Future<void> refetch() async {
    _data.value = null;
    await _fetchFirstPage();
  }

  /// Smart sync - refetch if stale
  Future<void> sync({bool force = false}) async {
    await waitForHydration();

    if (force || (_data.value == null || isStale)) {
      await refetch();
    }
  }

  /// Invalidate query (mark as stale)
  void invalidate() {
    _isStale.value = true;
  }

  /// Set data manually (for optimistic updates)
  void setData(InfiniteData<TData> data) {
    _data.value = data;
    _status.value = QueryStatus.success;
    _lastFetched.value = DateTime.now();
    _isStale.value = false;
  }

  void _completeHydration() {
    if (!isHydrated) {
      isHydrated = true;
      _hydrationCompleter.complete();
    }
  }

  QueryError _createQueryError(dynamic error) {
    if (error is QueryError) return error;

    return QueryError(
      error.toString(),
      QueryErrorType.unknown,
      error,
      StackTrace.current,
    );
  }

  /// Cancel any ongoing request
  void cancel() {
    print('🛑 CANCELING INFINITE QUERY REQUEST');

    // Clean up request tracking - this prevents the result from being processed
    // Note: We can't actually cancel the underlying HTTP request without Dio's CancelToken
    // but we can ignore the result when it arrives
    _currentFetch = null;
  }

  /// Dispose and clean up resources
  void dispose() {
    print('🗑️ DISPOSE INFINITE QUERY: ${queryKey.key}');

    // Mark as disposed to prevent future signal updates
    _isDisposed = true;

    // Cancel any ongoing requests
    cancel();

    // Signals will be automatically disposed by the signals library
    print('✅ DISPOSED INFINITE QUERY: ${queryKey.key}');
  }
}
