import 'dart:async';
import 'package:query_signals/query_signals/logging.dart';
import 'package:query_signals/query_signals/models/query_cached_data.model.dart';
import 'package:query_signals/query_signals/models/query_error.model.dart';
import 'package:query_signals/query_signals/models/query_key.model.dart';
import 'package:query_signals/query_signals/models/query_options.model.dart';
import 'package:signals/signals_flutter.dart';
import 'enums/query_status.enum.dart';
import 'client/query_client.dart';
import 'package:dio/dio.dart';
import 'types/query.type.dart';

/// A signal that becomes a no-op when disposed (graceful instead of throwing)
class _DisposalAwareSignal<T> extends Signal<T> {
  _DisposalAwareSignal(super.initialValue);

  @override
  set value(T newValue) {
    if (!disposed) {
      super.value = newValue;
    }
  }
}

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
  /// Cancel token for cancelling the request
  final _cancelToken = CancelToken();
  // Hydration tracking (for loading cached data before UI shows)
  bool isHydrated = false;
  final Completer<void> _hydrationCompleter = Completer<void>();

  /// Whether this query was reused from cache (not newly created)
  /// Used by mixins to decide whether to dispose it
  bool isReused = false;

  /// Whether this query has been disposed - prevents signal updates after disposal
  bool _isDisposed = false;

  /// Check if this query has been disposed (graceful handling)
  /// Returns false if disposed, true if can proceed with operations
  bool get _canOperate => !_isDisposed;

  final QueryKey queryKey;
  final QueryFn<TQueryFnData> queryFn;
  final QueryOptions<TData, TQueryFnData> options;
  final QueryClient _client;

  late final _DisposalAwareSignal<QueryStatus> _status;
  late final _DisposalAwareSignal<TData?> _data;
  late final _DisposalAwareSignal<QueryError?> _error;
  late final _DisposalAwareSignal<DateTime?> _lastFetched;
  late final _DisposalAwareSignal<bool> _isStale;

  Future<TData?>? _currentFetch; // Request deduplication
  bool _isFetching = false; // Track any fetch operation
  bool _hasTimedOut = false; // Track if current request has timed out
  Timer? _timeoutTimer;
  Timer? _refetchIntervalTimer;

  // Signal watching - store values for sync comparison or effect cleanup
  List<dynamic>? _lastSignalValues;
  void Function()? _signalWatcherDispose;

  // Pre-configured logger for this query with query-specific log level
  late final QueryLogger _logger;

  Query({
    required this.queryKey,
    required this.queryFn,
    required this.options,
    required QueryClient client,
  }) : _client = client {
    _status = _DisposalAwareSignal(QueryStatus.idle);
    _data = _DisposalAwareSignal<TData?>(null);
    _error = _DisposalAwareSignal<QueryError?>(null);
    _lastFetched = _DisposalAwareSignal<DateTime?>(null);
    _isStale = _DisposalAwareSignal(true);

    // Initialize logger with query-specific log level
    _logger = _client.createQueryLogger(options.logLevel);

    _setupSignalWatching();

    // Auto-fetch if enabled (like React Query's default behavior)
    if (options.enabled) {
      _logger.info('Query created - will fetch data', key: key);
      _initQuery();
    } else {
      _logger.info('Query created - disabled', key: key);
    }
  }

  // ==================== REACTIVE GETTERS ====================
  // These are the main properties you'll use in your widgets

  /// Current status of the query (idle, loading, success, error)
  QueryStatus get status => _status.value;
  QueryKey get key => queryKey;

  /// The transformed data (null if loading or error)
  TData? get data {
    // For sync approach (refetchOnSignalChange = false), check signals
    if (!options.refetchOnSignalChange && _checkSignalChanges()) {
      markStale();
    }

    final data = _data.value;
    if (data != null && _lastFetched.value != null) {
      final age = DateTime.now().difference(_lastFetched.value!);
      _logger.debug(
        'Data accessed - ${age.inSeconds}s old',
        key: key,
      );
    }

    return data;
  }

  /// Error object if query failed
  QueryError? get error => _error.value;

  /// Convenient boolean flags for common UI states
  bool get isLoading => _status.value == QueryStatus.loading;
  bool get isSuccess => _status.value == QueryStatus.success;
  bool get isError => _status.value == QueryStatus.error;
  bool get isIdle => _status.value == QueryStatus.idle;

  /// Whether data is stale and should be refetched (calculated dynamically)
  bool get isStale {
    // For sync approach (refetchOnSignalChange = false), check signals
    if (!options.refetchOnSignalChange && _checkSignalChanges()) {
      markStale();
    }

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
      _logger.error(
        'Init failed - $e',
        key: key,
        error: e,
      );
      _completeHydration();
    }
  }

  /// Set up signal watching - choose between sync and reactive approaches
  void _setupSignalWatching() {
    final watchSignals = options.watchSignals;
    if (watchSignals == null || watchSignals.isEmpty) {
      return;
    }

    // Store initial values
    _lastSignalValues = <dynamic>[];
    for (final signal in watchSignals) {
      _lastSignalValues!.add(signal.value);
    }

    // Choose approach based on refetchOnSignalChange
    if (options.refetchOnSignalChange) {
      // Reactive approach - refetch when signals change, but respect ongoing fetches
      _signalWatcherDispose = effect(() {
        bool hasChanged = false;

        // Check each signal for changes
        for (int i = 0; i < watchSignals.length; i++) {
          final currentValue = watchSignals[i].value;
          if (currentValue != _lastSignalValues![i]) {
            _lastSignalValues![i] = currentValue;
            hasChanged = true;
          }
        }

        // Refetch if something changed and query is enabled
        // Note: refetch() handles deduplication, so this is safe even with rapid changes
        if (hasChanged && options.enabled) {
          _logger.info(
            'Signal changed - reactive refetch',
            key: key,
          );
          markStale();
          refetch();
        }
      });
    }
    // For refetchOnSignalChange = false, we use sync checking in data getter
  }

  /// Check if watched signals have changed (sync approach)
  bool _checkSignalChanges() {
    final watchSignals = options.watchSignals;
    if (watchSignals == null ||
        watchSignals.isEmpty ||
        _lastSignalValues == null) {
      return false;
    }

    bool hasChanged = false;
    for (int i = 0; i < watchSignals.length; i++) {
      final currentValue = watchSignals[i].value;
      if (currentValue != _lastSignalValues![i]) {
        _lastSignalValues![i] = currentValue;
        hasChanged = true;
      }
    }

    return hasChanged;
  }

  /// Load and transform cached data if available
  Future<QueryCachedData<TData>?> _loadCachedData() async {
    final rawCachedData = await _client.getCachedData<dynamic>(
      key,
      granularUpdates: options.granularUpdates,
    );
    final cachedTime = await _client.getCachedTime(key);

    if (rawCachedData == null || cachedTime == null) {
      return null;
    }

    try {
      final transformedData = _transformCachedData(rawCachedData);
      return QueryCachedData(transformedData, cachedTime);
    } catch (e) {
      _logger.error(
        'Cache transform error - $e',
        key: key,
        error: e,
      );
      return null;
    }
  }

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

    final age = DateTime.now().difference(cachedData.time);
    final cacheDuration =
        options.cacheDuration ?? _client.config.defaultCacheDuration;

    _logger.info(
      'Cache hit - loaded ${age.inSeconds}s old data',
      key: key,
    );

    // If cached data is fresh, we're done!
    if (!isStale) {
      _logger.debug(
        'Cache fresh - no refresh needed',
        key: key,
      );
      return;
    }

    // If stale but still within cache duration, show cached data
    // and fetch fresh data in background (React Query's stale-while-revalidate)
    if (age <= cacheDuration) {
      _logger.info(
        'Cache stale but valid - background refresh',
        key: key,
      );
      _fetchInBackground();
    } else {
      _logger.info(
        'Cache expired - foreground refresh',
        key: key,
      );
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
    if (!_canOperate) {
      _logger.warn(
        'Refetch skipped - query disposed',
        key: key,
      );
      return null;
    }

    // For sync approach (refetchOnSignalChange = false), check signals
    if (!options.refetchOnSignalChange && _checkSignalChanges()) {
      markStale();
    }

    // Return existing request if already in progress
    if (_currentFetch != null) {
      _logger.debug(
        'Dedupe fetch - returning existing request',
        key: key,
      );
      return _currentFetch;
    }

    _isFetching = true;
    _currentFetch = _performFetch();
    try {
      final result = await _currentFetch!;
      _logger.info(
        'Refetch success',
        key: key,
      );
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
      // Reset timeout flag for new request
      _hasTimedOut = false;

      // Set loading state
      _status.value = QueryStatus.loading;
      _error.value = null;

      // Set up timeout
      final timeout = options.requestTimeout ?? _client.config.requestTimeout;
      _timeoutTimer = Timer(timeout, () {
        _hasTimedOut = true;
        _logger.warn(
          'Request timeout after ${timeout.inSeconds}s',
          key: key,
        );
        _error.value = QueryError(
          'Request timed out after ${timeout.inSeconds}s',
          QueryErrorType.timeout,
        );
        _status.value = QueryStatus.timeout;
      });

      // Call the raw API function with context
      final ctx = QueryFnContext(
        cancelToken: _cancelToken,
        queryKey: key.key,
      );
      final rawResult = await queryFn(ctx);

      // Cancel timeout timer since we got a response
      _timeoutTimer?.cancel();
      _timeoutTimer = null;

      // If request has already timed out, don't process the late response
      if (_hasTimedOut) {
        _logger.warn(
          'Ignoring late response after timeout',
          key: key,
        );
        return null;
      }

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

      // Cache the raw API result for consistent transformation
      await _client.setCachedData(
        key,
        rawResult,
        granularUpdates: options.granularUpdates,
      );
      await _client.setCachedTime(key, DateTime.now());

      // Update all signals with success state
      _data.value = transformedResult;
      _status.value = QueryStatus.success;
      _lastFetched.value = DateTime.now();
      _isStale.value = false;

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

      _logger.error(
        'Fetch error - ${queryError.message} (${queryError.type})',
        key: key,
        error: queryError,
      );

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
    if (_isFetching) {
      return;
    }

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
      final ctx = QueryFnContext(
        cancelToken: _cancelToken,
        queryKey: key.key,
      );
      final rawResult = await queryFn(ctx);

      // Transform data with same type safety as main fetch
      late final TData transformedResult;

      if (options.transformer != null) {
        transformedResult = options.transformer!(rawResult);
      } else {
        if (rawResult is TData) {
          transformedResult = rawResult;
        } else {
          // Background transformation failed - log error and mark as stale
          _logger.error(
            'Background fetch transform error - type mismatch: Expected $TData but got ${rawResult.runtimeType}',
            key: key,
            error: rawResult,
          );
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
        key,
        rawResult,
        granularUpdates: options.granularUpdates,
      );
      await _client.setCachedTime(key, DateTime.now());

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

  /// Mark query as stale without refetching
  void markStale() {
    _isStale.value = true;
  }

  /// Mark query as stale and refetch if enabled
  void invalidate() {
    _logger.info(
      'Query invalidated',
      key: key,
    );
    _isStale.value = true;
    if (options.enabled) {
      refetch();
    }
  }

  /// Sync with server - only fetches if stale/missing, unless forced
  Future<void> sync({bool force = false}) async {
    if (!_canOperate) {
      _logger.warn(
        'Sync skipped - query disposed',
        key: key,
      );
      return;
    }

    // Wait for hydration to complete first - cached data might be loading
    await waitForHydration();

    // Don't double-fetch if any fetch is already in progress
    if (!force && _isFetching) {
      return;
    }

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
    _logger.info(
      'Data set manually',
      key: key,
    );
    _data.value = newData;
    _status.value = QueryStatus.success;
    _lastFetched.value = DateTime.now();
    _isStale.value = false;

    // For manual data setting, we store the transformed data since we don't have raw data
    // This is a special case for optimistic updates
    _client.setCachedData(
      key,
      newData,
      granularUpdates: options.granularUpdates,
    );
    _client.setCachedTime(key, DateTime.now());
  }

  /// Cancel query and clean up any ongoing operations
  void cancel() {
    _cancelToken.cancel('Query ${key.key} cancelled');
    // Clean up request tracking - this prevents the result from being processed
    // Note: We can't actually cancel the underlying HTTP request without Dio's CancelToken
    // but we can ignore the result when it arrives
    _currentFetch = null;
    _isFetching = false;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
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

    _refetchIntervalTimer = Timer.periodic(interval, (timer) {
      // Only refetch if query is still enabled
      if (!options.enabled) {
        _stopRefetchInterval();
        return;
      }

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
    // Mark as disposed to prevent future signal updates
    _isDisposed = true;
    _logger.verbose(
      'Query dispose',
      key: key,
    );

    // Cancel any ongoing requests
    cancel();

    // Cancel any pending operations
    _stopRefetchInterval();

    // Clean up signal watching
    _signalWatcherDispose?.call();
    _lastSignalValues = null;

    // Dispose signals (they become no-ops for future writes)
    _status.dispose();
    _data.dispose();
    _error.dispose();
    _lastFetched.dispose();
    _isStale.dispose();

    // Remove from client
    _client.removeQuery(key);
  }
}
