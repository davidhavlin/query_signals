import '../logging.dart';

/// Configuration for QueryClient default behaviors
class QueryClientConfig {
  /// Default stale duration - how long data stays fresh (no background refetch)
  final Duration defaultStaleDuration;

  /// Default cache duration - how long data stays in memory (default: infinite)
  final Duration defaultCacheDuration;

  /// Whether to refetch on window focus (web/desktop)
  final bool refetchOnWindowFocus;

  /// Whether to refetch when network reconnects
  final bool refetchOnReconnect;

  /// Request timeout duration
  final Duration requestTimeout;

  /// Global logging level for the entire query_signals package
  /// Individual queries can override this with their own logLevel
  final QuerySignalsLogLevel logLevel;

  const QueryClientConfig({
    this.defaultStaleDuration = const Duration(minutes: 5),
    this.defaultCacheDuration =
        const Duration(days: 365 * 100), // Effectively infinite
    this.refetchOnWindowFocus = true,
    this.refetchOnReconnect = true,
    this.requestTimeout = const Duration(seconds: 30),
    this.logLevel = QuerySignalsLogLevel.none,
  });
}
