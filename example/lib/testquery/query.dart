import 'dart:async';
import 'package:signals/signals_flutter.dart';
import 'query_types.dart';
import 'query_client.dart';

/// A reactive query that handles data fetching, caching, and state management
/// Similar to React Query's useQuery but with Flutter signals for reactivity
///
/// Usage in widgets:
/// ```dart
/// Watch((context) {
///   if (query.isLoading) return CircularProgressIndicator();
///   if (query.isError) return Text('Error: ${query.error}');
///   return Text('Data: ${query.data}');
/// })
/// ```
class Query<TData extends Object?, TQueryFnData extends Object?> {
  final QueryKey queryKey;
  final Future<TQueryFnData> Function() queryFn; // Raw API call
  final QueryOptions<TData, TQueryFnData> options;
  final QueryClient _client;

  // Internal signals that power the reactivity
  late final Signal<QueryStatus> _status;
  late final Signal<TData?> _data;
  late final Signal<QueryError?> _error;
  late final Signal<DateTime?> _lastFetched;
  late final Signal<bool> _isStale;

  // Memoized computed signals for performance
  late final FlutterComputed<bool> _isLoadingSignal;
  late final FlutterComputed<bool> _isSuccessSignal;
  late final FlutterComputed<bool> _isErrorSignal;

  // Hydration tracking (for loading cached data before UI shows)
  bool isHydrated = false;
  final Completer<void> _hydrationCompleter = Completer<void>();

  // Request deduplication
  Future<TData?>? _currentFetch;
  Timer? _timeoutTimer;

  Query({
    required this.queryKey,
    required this.queryFn,
    required this.options,
    required QueryClient client,
  }) : _client = client {
    // Initialize all signals with default states
    _status = signal(QueryStatus.idle);
    _data = signal<TData?>(null);
    _error = signal<QueryError?>(null);
    _lastFetched = signal<DateTime?>(null);
    _isStale = signal(true);

    // Initialize memoized computed signals
    _isLoadingSignal = computed(() => _status.value == QueryStatus.loading);
    _isSuccessSignal = computed(() => _status.value == QueryStatus.success);
    _isErrorSignal = computed(() => _status.value == QueryStatus.error);

    // Auto-fetch if enabled (like React Query's default behavior)
    if (options.enabled) {
      _initQuery();
    }
  }

  // ==================== REACTIVE GETTERS ====================
  // These are the main properties you'll use in your widgets

  /// Current status of the query (idle, loading, success, error)
  QueryStatus get status => _status.value;

  /// The transformed data (null if loading or error)
  TData? get data => _data.value;

  /// Error object if query failed
  QueryError? get error => _error.value;

  /// Convenient boolean flags for common UI states
  bool get isLoading => _status.value == QueryStatus.loading;
  bool get isSuccess => _status.value == QueryStatus.success;
  bool get isError => _status.value == QueryStatus.error;
  bool get isIdle => _status.value == QueryStatus.idle;

  /// Whether data is stale and should be refetched
  bool get isStale => _isStale.value;

  /// When data was last successfully fetched
  DateTime? get lastFetched => _lastFetched.value;

  /// Wait for cached data to load before showing UI
  /// Call this in main() to avoid loading flicker on app start
  Future<void> waitForHydration() => _hydrationCompleter.future;

  // ==================== SIGNAL GETTERS FOR WATCH ====================
  // Use these with Watch() widget for granular reactivity

  /// Direct access to status signal for Watch widgets
  Signal<QueryStatus> get statusSignal => _status;

  /// Direct access to data signal for Watch widgets
  Signal<TData?> get dataSignal => _data;

  /// Direct access to error signal for Watch widgets
  Signal<QueryError?> get errorSignal => _error;

  /// Memoized computed signals for boolean states
  FlutterComputed<bool> get isLoadingSignal => _isLoadingSignal;
  FlutterComputed<bool> get isSuccessSignal => _isSuccessSignal;
  FlutterComputed<bool> get isErrorSignal => _isErrorSignal;

  // ==================== QUERY LIFECYCLE ====================

  /// Initialize query - check cache first, then fetch if needed
  Future<void> _initQuery() async {
    try {
      // Step 1: Try to load from cache (for instant UI)
      final cachedData = await _client.getCachedData<TData>(
        queryKey,
        granularUpdates: options.granularUpdates,
      );
      final cachedTime = await _client.getCachedTime(queryKey);

      if (cachedData != null && cachedTime != null) {
        // Show cached data immediately
        _data.value = cachedData;
        _lastFetched.value = cachedTime;
        _status.value = QueryStatus.success;

        // Check if data is stale
        final isStale =
            DateTime.now().difference(cachedTime) > options.staleDuration!;
        _isStale.value = isStale;

        // Mark as hydrated (cached data loaded)
        _completeHydration();

        // If data is fresh, we're done!
        if (!isStale) return;

        // If stale but still within cache duration, show cached data
        // and fetch fresh data in background (React Query's stale-while-revalidate)
        if (DateTime.now().difference(cachedTime) <= options.cacheDuration!) {
          _fetchInBackground();
          return;
        }
      } else {
        // No cached data - mark as hydrated anyway (nothing to load)
        _completeHydration();
      }

      // No cache or cache expired - fetch fresh data with loading state
      await refetch();
    } catch (e) {
      // Always complete hydration even on error
      _completeHydration();
    }
  }

  /// Mark hydration as complete
  void _completeHydration() {
    if (!isHydrated) {
      isHydrated = true;
      _hydrationCompleter.complete();
    }
  }

  /// Manually refetch data (e.g., pull-to-refresh) with request deduplication
  Future<TData?> refetch() async {
    // Return existing request if already in progress
    if (_currentFetch != null) {
      return _currentFetch;
    }

    _currentFetch = _performFetch();
    try {
      final result = await _currentFetch!;
      return result;
    } finally {
      _currentFetch = null;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
    }
  }

  /// Internal fetch implementation with timeout and better error handling
  Future<TData?> _performFetch() async {
    try {
      // Set loading state
      _status.value = QueryStatus.loading;
      _error.value = null;

      // Set up timeout
      final timeout = options.requestTimeout ?? _client.config.requestTimeout;
      _timeoutTimer = Timer(timeout, () {
        _error.value = QueryError(
          'Request timed out after ${timeout.inSeconds}s',
          QueryErrorType.timeout,
        );
        _status.value = QueryStatus.timeout;
      });

      // Call the raw API function
      final rawResult = await queryFn();

      // Cancel timeout timer since we got a response
      _timeoutTimer?.cancel();
      _timeoutTimer = null;

      // Transform raw data to model using transformer function with type safety
      late final TData transformedResult;

      if (options.transformer != null) {
        transformedResult = options.transformer!(rawResult);
      } else {
        // Type-safe casting instead of unsafe as cast
        if (rawResult is TData) {
          transformedResult = rawResult;
        } else {
          throw QueryError(
            'Type mismatch: Expected $TData but got ${rawResult.runtimeType}',
            QueryErrorType.parsing,
            rawResult,
          );
        }
      }

      // Update all signals with success state
      _data.value = transformedResult;
      _status.value = QueryStatus.success;
      _lastFetched.value = DateTime.now();
      _isStale.value = false;

      // Cache the transformed result for future use
      await _client.setCachedData(
        queryKey,
        transformedResult,
        granularUpdates: options.granularUpdates,
      );
      await _client.setCachedTime(queryKey, DateTime.now());

      return transformedResult;
    } catch (e, stackTrace) {
      // Handle errors gracefully with better error categorization
      late final QueryError queryError;

      if (e is QueryError) {
        queryError = e;
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        queryError = QueryError(
          'Network timeout: ${e.toString()}',
          QueryErrorType.timeout,
          e,
          stackTrace,
        );
        _status.value = QueryStatus.timeout;
      } else if (e.toString().contains('network') ||
          e.toString().contains('socket') ||
          e.toString().contains('connection')) {
        queryError = QueryError(
          'Network error: ${e.toString()}',
          QueryErrorType.network,
          e,
          stackTrace,
        );
        _status.value = QueryStatus.networkError;
      } else {
        queryError = QueryError(
          e.toString(),
          QueryErrorType.unknown,
          e,
          stackTrace,
        );
        _status.value = QueryStatus.error;
      }

      _error.value = queryError;
      _isStale.value = true;
      return null;
    }
  }

  /// Fetch in background without showing loading state (silent refresh)
  Future<void> _fetchInBackground() async {
    try {
      // Call API function
      final rawResult = await queryFn();

      // Transform data with same type safety as main fetch
      late final TData transformedResult;

      if (options.transformer != null) {
        transformedResult = options.transformer!(rawResult);
      } else {
        if (rawResult is TData) {
          transformedResult = rawResult;
        } else {
          // Silent fail for background refresh - just mark as stale
          _isStale.value = true;
          return;
        }
      }

      // Update data silently (no loading state change)
      _data.value = transformedResult;
      _lastFetched.value = DateTime.now();
      _isStale.value = false;

      // Update cache
      await _client.setCachedData(
        queryKey,
        transformedResult,
        granularUpdates: options.granularUpdates,
      );
      await _client.setCachedTime(queryKey, DateTime.now());
    } catch (e) {
      // Silent fail for background refresh - just mark as stale
      _isStale.value = true;
    }
  }

  // ==================== MANUAL CONTROLS ====================

  /// Mark query as stale and refetch if enabled
  void invalidate() {
    _isStale.value = true;
    if (options.enabled) {
      refetch();
    }
  }

  /// Manually set data (useful for optimistic updates)
  void setData(TData newData) {
    _data.value = newData;
    _status.value = QueryStatus.success;
    _lastFetched.value = DateTime.now();
    _isStale.value = false;

    // Update cache with new data
    _client.setCachedData(
      queryKey,
      newData,
      granularUpdates: options.granularUpdates,
    );
    _client.setCachedTime(queryKey, DateTime.now());
  }

  /// Clean up query when no longer needed
  /// Disposes all signals to prevent memory leaks
  void dispose() {
    // Cancel any pending operations
    _timeoutTimer?.cancel();
    _currentFetch = null;

    // Dispose all signals
    _status.dispose();
    _data.dispose();
    _error.dispose();
    _lastFetched.dispose();
    _isStale.dispose();

    // Dispose memoized computed signals
    _isLoadingSignal.dispose();
    _isSuccessSignal.dispose();
    _isErrorSignal.dispose();

    // Remove from client
    _client.removeQuery(queryKey);
  }
}
