import 'package:query_signals/query_signals/models/infinite_query_data.model.dart';
import 'package:query_signals/query_signals/models/query_error.model.dart';

/// Configuration options for infinite queries
class InfiniteQueryOptions<TData extends Object?, TQueryFnData extends Object?,
    TPageParam extends Object?> {
  /// How long data stays fresh before being considered stale
  final Duration? staleDuration;

  /// How long data stays in cache before being garbage collected
  final Duration? cacheDuration;

  /// Whether the query should automatically run when created (default: true)
  final bool enabled;

  /// Whether to refetch data when component mounts (default: true)
  final bool refetchOnMount;

  /// Transform raw API data into page data
  final TData Function(TQueryFnData)? transformer;

  /// Determine the next page parameter from the last page and all pages
  /// Return null/undefined to indicate no more pages
  /// Example: (lastPage, allPages) => lastPage.hasMore ? allPages.length : null
  final TPageParam? Function(TData lastPage, List<TData> allPages)?
      getNextPageParam;

  /// Determine the previous page parameter (for bidirectional pagination)
  final TPageParam? Function(TData firstPage, List<TData> allPages)?
      getPreviousPageParam;

  /// Initial page parameter (default: usually 0 or 1)
  final TPageParam? initialPageParam;

  /// Request timeout (overrides QueryClient default)
  final Duration? requestTimeout;

  /// Automatically refetch at regular intervals
  final Duration? refetchInterval;

  /// Dynamic refetch interval based on current state (data, error)
  final Duration? Function(InfiniteData<TData>? data, QueryError? error)?
      refetchIntervalFn;

  const InfiniteQueryOptions({
    this.staleDuration,
    this.cacheDuration,
    this.enabled = true,
    this.refetchOnMount = true,
    this.transformer,
    this.getNextPageParam,
    this.getPreviousPageParam,
    this.initialPageParam,
    this.requestTimeout,
    this.refetchInterval,
    this.refetchIntervalFn,
  });
}
