import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'query.dart';
import 'query_client.dart';
import 'types/query_types.dart';

/// Widget that automatically creates and disposes a query
/// Perfect for one-off queries that are only used in specific widgets
///
/// The query is automatically disposed when the widget is disposed,
/// preventing memory leaks without manual management.
///
/// Example:
/// ```dart
/// AutoDisposingQuery<List<Post>, List<dynamic>>(
///   queryKey: ['posts'],
///   queryFn: () => api.get('/posts'),
///   transformer: (json) => json.map((e) => Post.fromJson(e)).toList(),
///   builder: (context, query) {
///     if (query.isLoading) return CircularProgressIndicator();
///     return PostsList(posts: query.data ?? []);
///   },
/// )
/// ```
class AutoDisposingQuery<TData extends Object?, TQueryFnData extends Object?>
    extends StatefulWidget {
  final List<dynamic> queryKey;
  final Future<TQueryFnData> Function() queryFn;
  final TData Function(TQueryFnData)? transformer;
  final QueryOptions<TData, TQueryFnData>? options;
  final Widget Function(BuildContext context, Query<TData, TQueryFnData> query)
      builder;

  const AutoDisposingQuery({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.transformer,
    this.options,
  });

  @override
  State<AutoDisposingQuery<TData, TQueryFnData>> createState() =>
      _AutoDisposingQueryState<TData, TQueryFnData>();
}

class _AutoDisposingQueryState<TData extends Object?,
        TQueryFnData extends Object?>
    extends State<AutoDisposingQuery<TData, TQueryFnData>> {
  late final Query<TData, TQueryFnData> _query;
  final _client = QueryClient();
  bool _isQueryOwner = false;

  @override
  void initState() {
    super.initState();

    // Check if this query already exists (shared)
    final existingData = _client.getQueryData<TData>(widget.queryKey);
    _isQueryOwner = existingData == null;

    // Create query with auto-disposal tracking
    _query = _client.useQuery<TData, TQueryFnData>(
      widget.queryKey,
      widget.queryFn,
      options: widget.options?.copyWith(transformer: widget.transformer) ??
          QueryOptions(transformer: widget.transformer),
    );
  }

  @override
  void dispose() {
    // Only dispose if this widget "owns" the query (created it first)
    // If query is shared with other widgets, don't dispose
    if (_isQueryOwner) {
      _query.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _query);
  }
}

/// Extension to add copyWith to QueryOptions
extension QueryOptionsExtension<TData extends Object?,
    TQueryFnData extends Object?> on QueryOptions<TData, TQueryFnData> {
  QueryOptions<TData, TQueryFnData> copyWith({
    Duration? staleDuration,
    Duration? cacheDuration,
    bool? enabled,
    bool? refetchOnMount,
    TData Function(TQueryFnData)? transformer,
    bool? granularUpdates,
    Duration? requestTimeout,
  }) {
    return QueryOptions<TData, TQueryFnData>(
      staleDuration: staleDuration ?? this.staleDuration,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      enabled: enabled ?? this.enabled,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      transformer: transformer ?? this.transformer,
      granularUpdates: granularUpdates ?? this.granularUpdates,
      requestTimeout: requestTimeout ?? this.requestTimeout,
    );
  }
}

/// Stateless version that uses Watch for rebuilding
/// Even more convenient for simple cases
///
/// Example:
/// ```dart
/// QueryWatch<List<Post>, List<dynamic>>(
///   queryKey: ['posts'],
///   queryFn: () => api.get('/posts'),
///   transformer: (json) => json.map((e) => Post.fromJson(e)).toList(),
///   builder: (context, query) {
///     if (query.isLoading) return CircularProgressIndicator();
///     return Text('Posts: ${query.data?.length ?? 0}');
///   },
/// )
/// ```
class QueryWatch<TData extends Object?, TQueryFnData extends Object?>
    extends StatelessWidget {
  final List<dynamic> queryKey;
  final Future<TQueryFnData> Function() queryFn;
  final TData Function(TQueryFnData)? transformer;
  final QueryOptions<TData, TQueryFnData>? options;
  final Widget Function(BuildContext context, Query<TData, TQueryFnData> query)
      builder;

  const QueryWatch({
    super.key,
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.transformer,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final client = QueryClient();
    final query = client.useQuery<TData, TQueryFnData>(
      queryKey,
      queryFn,
      options: options?.copyWith(transformer: transformer) ??
          QueryOptions(transformer: transformer),
    );

    return Watch((context) => builder(context, query));
  }
}
