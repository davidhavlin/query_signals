import 'package:query_signals/query_signals/models/query_error.model.dart';
import 'package:signals/signals_flutter.dart';
import '../logging.dart';

/// Configuration options for queries - similar to React Query's useQuery options
class QueryOptions<TData extends Object?, TQueryFnData extends Object?> {
  /// How long data stays fresh before being considered stale
  /// If null, uses QueryClient's defaultStaleDuration
  /// When stale, data will be refetched in background on next access
  final Duration? staleDuration;

  /// How long data stays in cache before being garbage collected
  /// If null, uses QueryClient's defaultCacheDuration
  /// Cached data will be shown immediately while fresh data is fetched
  final Duration? cacheDuration;

  /// Whether the query should automatically run when created (default: true)
  final bool enabled;

  /// Whether to refetch data when component mounts (default: true)
  final bool refetchOnMount;

  /// Transform raw API data into your model - keeps API functions pure
  /// Example: (jsonList) => jsonList.map((json) => Post.fromJson(json)).toList()
  final TData Function(TQueryFnData)? transformer;

  /// Enable efficient storage for large lists (default: false)
  /// Only use this for lists with HasId items that change frequently
  /// When true: individual items stored separately, updates only touch changed items
  /// When false: entire list stored as JSON (simpler, good for small/static lists)
  final bool granularUpdates;

  /// Request timeout (overrides QueryClient default)
  final Duration? requestTimeout;

  /// Signals to watch - query will be marked as stale when any of these change
  /// Example: watchSignals: [userId, selectedCategory, searchTerm]
  /// By default, query is just marked stale and will refetch on next access
  final List<Signal>? watchSignals;

  /// Whether to immediately refetch when watched signals change (default: false)
  /// When false: signal changes just mark query as stale for next fetch
  /// When true: signal changes immediately trigger a refetch
  final bool refetchOnSignalChange;

  /// Automatically refetch at regular intervals (like React Query's refetchInterval)
  ///
  /// Examples:
  /// - `Duration(seconds: 30)` - refetch every 30 seconds
  /// - `(data, error) => data != null ? Duration(minutes: 1) : Duration(seconds: 10)` - dynamic interval
  /// - `null` - no automatic refetching (default)
  ///
  /// Useful for real-time data that needs to stay fresh
  final Duration? refetchInterval;

  /// Dynamic refetch interval based on current state (data, error)
  /// Takes precedence over refetchInterval if both are provided
  /// Example: `(data, error) => error != null ? Duration(seconds: 5) : Duration(minutes: 1)`
  final Duration? Function(TData? data, QueryError? error)? refetchIntervalFn;

  /// Logging level for this specific query - overrides global log level if set
  /// Useful for debugging specific queries or silencing noisy ones
  /// Examples:
  /// - `null` - use global log level (default)
  /// - `QuerySignalsLogLevel.debug` - enable debug logging for this query only
  /// - `QuerySignalsLogLevel.none` - disable logging for this query
  final QuerySignalsLogLevel? logLevel;

  const QueryOptions({
    this.staleDuration,
    this.cacheDuration,
    this.enabled = true,
    this.refetchOnMount = true,
    this.transformer,
    this.granularUpdates = false,
    this.requestTimeout,
    this.watchSignals,
    this.refetchOnSignalChange = false,
    this.refetchInterval,
    this.refetchIntervalFn,
    this.logLevel,
  });
}
