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
