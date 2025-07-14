import 'dart:async';
import 'package:query_signals/query_signals/models/query_cached_data.model.dart';
import 'package:query_signals/query_signals/models/query_error.model.dart';
import 'package:query_signals/query_signals/models/query_key.model.dart';
import 'package:query_signals/query_signals/models/query_options.model.dart';
import 'package:signals/signals_flutter.dart';
import 'enums/query_status.enum.dart';
import 'client/query_client.dart';

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
  bool _isFetching = false; // Track any fetch operation
  Timer? _timeoutTimer;
  Timer? _refetchIntervalTimer;

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

    // Set up signal watching - automatically refetch when watched signals change
    _setupSignalWatching();

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

  /// Whether data is stale and should be refetched (calculated dynamically)
  bool get isStale {
    // If manually invalidated, always stale
    if (_isStale.value) return true;

    final lastFetch = _lastFetched.value;
    // If no data exists, it's not "stale" - it's just missing
    if (lastFetch == null) return false;

    final staleDuration =
        options.staleDuration ?? _client.config.defaultStaleDuration;
    return DateTime.now().difference(lastFetch) > staleDuration;
  }

  /// Whether query needs to fetch data (no data OR data is stale)
  bool get needsFetch {
    return _data.value == null || isStale;
  }

  /// Whether data is expired and needs loading refresh (not just background)
  bool get isExpired {
    final lastFetch = _lastFetched.value;
    if (lastFetch == null) return true; // No data = expired

    final cacheDuration =
        options.cacheDuration ?? _client.config.defaultCacheDuration;
    return DateTime.now().difference(lastFetch) > cacheDuration;
  }

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
      final cachedData = await _loadCachedData();

      if (cachedData != null) {
        await _handleCachedData(cachedData);
      } else {
        _completeHydration();
        await refetch();
      }
    } catch (e) {
      print('Error initializing query: $e');
      _completeHydration();
    }
  }

  /// Set up signal watching - subscribes to signals and invalidates query when they change
  void _setupSignalWatching() {
    final watchSignals = options.watchSignals;
    if (watchSignals == null || watchSignals.isEmpty) return;

    // Create an effect that watches all signals and invalidates query when any change
    effect(() {
      // Read all watched signals to create dependencies
      for (final signal in watchSignals) {
        signal.value; // Reading the value creates the dependency
      }

      // Skip the first run (initialization)
      if (_status.value == QueryStatus.idle) return;

      // Invalidate and refetch when any watched signal changes
      print('Signal dependency changed, invalidating query: ${queryKey.key}');
      invalidate();

      // Auto-refetch if query is enabled
      if (options.enabled) {
        sync();
      }
    });
  }

  /// Load and transform cached data if available
  Future<QueryCachedData<TData>?> _loadCachedData() async {
    final rawCachedData = await _client.getCachedData<dynamic>(
      queryKey,
      granularUpdates: options.granularUpdates,
    );
    final cachedTime = await _client.getCachedTime(queryKey);

    if (rawCachedData == null || cachedTime == null) return null;

    try {
      final transformedData = _transformCachedData(rawCachedData);
      return QueryCachedData(transformedData, cachedTime);
    } catch (e) {
      print('Failed to transform cached data: $e');
      return null;
    }
  }

  /// Transform cached data using the same logic as fresh API data
  TData _transformCachedData(dynamic rawData) {
    if (options.transformer != null) {
      try {
        // Try to transform as raw API data first
        final typedData = rawData as TQueryFnData;
        return options.transformer!(typedData);
      } catch (e) {
        // If transformation fails, assume data is already transformed (from setData)
        if (rawData is TData) {
          return rawData;
        } else {
          rethrow;
        }
      }
    } else {
      // Direct cast if no transformer
      if (rawData is TData) {
        return rawData;
      } else {
        throw QueryError(
          'Cached data type mismatch: Expected $TData but got ${rawData.runtimeType}',
          QueryErrorType.parsing,
          rawData,
        );
      }
    }
  }

  /// Handle cached data - decide whether to use it, fetch fresh, or background refresh
  Future<void> _handleCachedData(QueryCachedData<TData> cachedData) async {
    // Show cached data immediately
    _data.value = cachedData.data;
    _lastFetched.value = cachedData.time;
    _status.value = QueryStatus.success;

    // Clear manual invalidation since we just loaded data
    _isStale.value = false;
    _completeHydration();

    // Start refetch interval for cached data
    _startRefetchInterval();

    print('handleCachedData: isStale=${isStale}');

    // If cached data is fresh, we're done!
    if (!isStale) return;

    // If stale but still within cache duration, show cached data
    // and fetch fresh data in background (React Query's stale-while-revalidate)
    if (DateTime.now().difference(cachedData.time) <= options.cacheDuration!) {
      _fetchInBackground();
    } else {
      // Cache expired - fetch fresh data with loading state
      await refetch();
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

    _isFetching = true;
    _currentFetch = _performFetch();
    try {
      final result = await _currentFetch!;
      return result;
    } finally {
      _currentFetch = null;
      _isFetching = false;
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

      // Cache the raw API result for consistent transformation
      await _client.setCachedData(
        queryKey,
        rawResult,
        granularUpdates: options.granularUpdates,
      );
      await _client.setCachedTime(queryKey, DateTime.now());

      // Start refetch interval after successful fetch
      _startRefetchInterval();

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

      print('queryKey: ${queryKey.toString()}');
      print('queryError: ${queryError.message}');
      print('queryError: ${queryError.type}');
      print('queryError: ${queryError.originalError}');
      print('queryError: ${queryError.stackTrace}');

      _error.value = queryError;
      _isStale.value = true;

      // Stop refetch interval on error
      _stopRefetchInterval();

      return null;
    }
  }

  /// Fetch in background without showing loading state (silent refresh)
  Future<void> _fetchInBackground() async {
    // Don't double-fetch if any operation is in progress
    if (_isFetching) return;

    _isFetching = true;
    try {
      await _performBackgroundFetch();
    } finally {
      _isFetching = false;
    }
  }

  /// Internal background fetch implementation
  Future<void> _performBackgroundFetch() async {
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

      // Cache the raw API result for consistent transformation
      await _client.setCachedData(
        queryKey,
        rawResult,
        granularUpdates: options.granularUpdates,
      );
      await _client.setCachedTime(queryKey, DateTime.now());

      // Restart refetch interval after successful background fetch (for dynamic intervals)
      if (options.refetchIntervalFn != null) {
        _startRefetchInterval();
      }
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

  /// Sync with server - only fetches if stale/missing, unless forced
  Future<void> sync({bool force = false}) async {
    // Wait for hydration to complete first - cached data might be loading
    await waitForHydration();

    print(
      'sync: expired=${isExpired}, stale=${isStale}, data=${_data.value != null}',
    );

    // Don't double-fetch if any fetch is already in progress
    if (!force && _isFetching) return;

    // Force always fetches with loading
    if (force) {
      await refetch();
      return;
    }

    // No data = fetch with loading
    if (_data.value == null) {
      await refetch();
      return;
    }

    // Data expired (cache duration exceeded) = fetch with loading
    if (isExpired) {
      await refetch();
      return;
    }

    // Data stale but not expired = background refresh (no loading)
    if (isStale) {
      _fetchInBackground();
      return;
    }

    // Data is fresh = do nothing
  }

  /// Manually set data (useful for optimistic updates)
  void setData(TData newData) {
    _data.value = newData;
    _status.value = QueryStatus.success;
    _lastFetched.value = DateTime.now();
    _isStale.value = false;

    // For manual data setting, we store the transformed data since we don't have raw data
    // This is a special case for optimistic updates
    _client.setCachedData(
      queryKey,
      newData,
      granularUpdates: options.granularUpdates,
    );
    _client.setCachedTime(queryKey, DateTime.now());
  }

  // ==================== REFETCH INTERVAL ====================

  /// Start automatic refetch interval based on options
  void _startRefetchInterval() {
    // Stop any existing timer first
    _stopRefetchInterval();

    // Don't start if query is disabled
    if (!options.enabled) return;

    // Calculate interval duration
    Duration? interval;

    if (options.refetchIntervalFn != null) {
      // Dynamic interval based on current state
      interval = options.refetchIntervalFn!(_data.value, _error.value);
    } else {
      // Fixed interval
      interval = options.refetchInterval;
    }

    // No interval configured
    if (interval == null) return;

    print(
        'Starting refetch interval: ${interval.inSeconds}s for query: ${queryKey.key}');

    _refetchIntervalTimer = Timer.periodic(interval, (timer) {
      // Only refetch if query is still enabled
      if (!options.enabled) {
        _stopRefetchInterval();
        return;
      }

      print('Refetch interval triggered for query: ${queryKey.key}');

      // Background refetch (no loading state)
      _fetchInBackground();

      // If using dynamic interval, restart with new interval
      if (options.refetchIntervalFn != null) {
        _startRefetchInterval();
      }
    });
  }

  /// Stop automatic refetch interval
  void _stopRefetchInterval() {
    _refetchIntervalTimer?.cancel();
    _refetchIntervalTimer = null;
  }

  /// Clean up query when no longer needed
  /// Disposes all signals to prevent memory leaks
  void dispose() {
    // Cancel any pending operations
    _timeoutTimer?.cancel();
    _stopRefetchInterval();
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
