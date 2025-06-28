/// Status of a query - matches React Query's status states
enum QueryStatus { idle, loading, success, error, timeout, networkError }

/// Specific error types for better error handling
class QueryError {
  final String message;
  final QueryErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const QueryError(
    this.message,
    this.type, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() => 'QueryError($type): $message';
}

enum QueryErrorType { network, timeout, parsing, server, unknown }

/// Data structure for infinite queries - holds all pages and page parameters
/// Similar to React Query's InfiniteData structure
class InfiniteData<TData> {
  final List<TData> pages;
  final List<dynamic> pageParams;

  const InfiniteData({required this.pages, required this.pageParams});

  /// Get flattened data from all pages
  /// Override this in subclasses if pages need custom flattening logic
  List<T> flatMap<T>(List<T> Function(TData page) mapper) {
    return pages.expand(mapper).toList();
  }

  /// Create new InfiniteData with additional page
  InfiniteData<TData> addPage(TData page, dynamic pageParam) {
    return InfiniteData(
      pages: [...pages, page],
      pageParams: [...pageParams, pageParam],
    );
  }

  /// Create new InfiniteData with replaced page at index
  InfiniteData<TData> replacePage(int index, TData page) {
    final newPages = [...pages];
    newPages[index] = page;
    return InfiniteData(pages: newPages, pageParams: pageParams);
  }

  /// Reset to empty state
  static InfiniteData<TData> empty<TData>() {
    return const InfiniteData(pages: [], pageParams: []);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InfiniteData<TData> &&
        pages.length == other.pages.length &&
        pageParams.length == other.pageParams.length;
  }

  @override
  int get hashCode => Object.hash(pages, pageParams);

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() => {'pages': pages, 'pageParams': pageParams};

  /// Create from cached JSON
  static InfiniteData<TData> fromJson<TData>(
    Map<String, dynamic> json,
    TData Function(dynamic) pageFromJson,
  ) {
    return InfiniteData<TData>(
      pages: (json['pages'] as List).map(pageFromJson).toList(),
      pageParams: json['pageParams'] as List,
    );
  }
}

/// Configuration for QueryClient default behaviors
class QueryClientConfig {
  /// Default stale duration - how long data stays fresh (no background refetch)
  final Duration defaultStaleDuration;

  /// Default cache duration - how long data stays in memory
  final Duration defaultCacheDuration;

  /// Whether to refetch on window focus (web/desktop)
  final bool refetchOnWindowFocus;

  /// Whether to refetch when network reconnects
  final bool refetchOnReconnect;

  /// Request timeout duration
  final Duration requestTimeout;

  const QueryClientConfig({
    this.defaultStaleDuration = const Duration(minutes: 5),
    this.defaultCacheDuration = const Duration(minutes: 30),
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.requestTimeout = const Duration(seconds: 30),
  });
}

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

  const QueryOptions({
    this.staleDuration,
    this.cacheDuration,
    this.enabled = true,
    this.refetchOnMount = true,
    this.transformer,
    this.granularUpdates = false,
    this.requestTimeout,
  });
}

/// Configuration options for infinite queries
class InfiniteQueryOptions<
  TData extends Object?,
  TQueryFnData extends Object?,
  TPageParam extends Object?
> {
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
  });
}

/// Configuration for mutations (create/update/delete operations)
class MutationOptions {
  /// Called when mutation succeeds - perfect for optimistic updates
  final Function(dynamic data)? onSuccess;

  /// Called when mutation fails - handle errors here
  final Function(QueryError error)? onError;

  /// Called when mutation completes (success or error) - cleanup here
  final Function()? onSettled;

  /// Request timeout for this mutation
  final Duration? requestTimeout;

  const MutationOptions({
    this.onSuccess,
    this.onError,
    this.onSettled,
    this.requestTimeout,
  });
}

/// Unique identifier for queries - used for caching and invalidation
/// Example: QueryKey(['posts']) or QueryKey(['posts', userId])
class QueryKey {
  final List<dynamic> key;
  int? _cachedHash; // Cache hash for performance

  QueryKey(this.key);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QueryKey) return false;
    if (key.length != other.key.length) return false;
    for (int i = 0; i < key.length; i++) {
      if (key[i] != other.key[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _cachedHash ??= Object.hashAll(key);

  @override
  String toString() => key.join('_');
}
