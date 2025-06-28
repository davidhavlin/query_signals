import 'package:flutter/material.dart';
import 'package:persist_signals/testquery/models/infinite_query_options.model.dart';
import 'package:persist_signals/testquery/models/query_mutation_options.model.dart';
import 'package:persist_signals/testquery/models/query_options.model.dart';
import '../query.dart';
import '../mutation.dart';
import '../infinite_query.dart';
import '../query_client.dart';
import '../enums/query_status.enum.dart';

/// Mixin that provides automatic query disposal when widget is disposed
/// Use this for simple, direct query usage in widgets without manual disposal
///
/// Example:
/// ```dart
/// class MyWidget extends StatefulWidget with QueryMixin {
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> with QueryMixin {
///   // Queries are automatically tracked and disposed
///   late final posts = client.useQuery<List<Post>, List<dynamic>>(
///     ['posts'],
///     fetchPostsApi,
///     transformer: (json) => json.map((e) => Post.fromJson(e)).toList(),
///   );
///
///   @override
///   Widget build(BuildContext context) {
///     return Watch((context) {
///       if (posts.isLoading) return CircularProgressIndicator();
///       return Text('Posts: ${posts.data?.length ?? 0}');
///     });
///   }
/// }
/// ```
mixin QueryMixin<T extends StatefulWidget> on State<T> {
  /// Global QueryClient instance (singleton)
  QueryClient get client => QueryClient();

  /// Track queries and mutations created by this widget for auto-disposal
  final Set<Query> _ownedQueries = {};
  final Set<InfiniteQuery> _ownedInfiniteQueries = {};
  final Set<Mutation> _ownedMutations = {};

  /// Create a query with automatic disposal tracking
  /// This replaces the manual client.useQuery() call
  Query<TData, TQueryFnData>
      useQuery<TData extends Object?, TQueryFnData extends Object?>(
    List<dynamic> key,
    Future<TQueryFnData> Function() queryFn, {
    QueryOptions<TData, TQueryFnData>? options,
  }) {
    final query = client.useQuery<TData, TQueryFnData>(
      key,
      queryFn,
      options: options,
    );

    // Only track as owned if this is a new query
    // If query already existed, it might be shared with other widgets
    if (!client.hasQuery(key)) {
      _ownedQueries.add(query);
    }

    return query;
  }

  /// Create an infinite query with automatic disposal tracking
  InfiniteQuery<TData, TQueryFnData, TPageParam> useInfiniteQuery<
      TData extends Object?,
      TQueryFnData extends Object?,
      TPageParam extends Object?>(
    List<dynamic> key,
    Future<TQueryFnData> Function(TPageParam pageParam) queryFn, {
    InfiniteQueryOptions<TData, TQueryFnData, TPageParam>? options,
  }) {
    final infiniteQuery =
        client.useInfiniteQuery<TData, TQueryFnData, TPageParam>(
      key,
      queryFn,
      options: options,
    );

    // Only track as owned if this is a new query
    if (!client.hasInfiniteQuery(key)) {
      _ownedInfiniteQueries.add(infiniteQuery);
    }

    return infiniteQuery;
  }

  /// Create a mutation with automatic disposal tracking
  Mutation<TData, TVariables>
      useMutation<TData extends Object?, TVariables extends Object?>(
    Future<TData> Function(TVariables variables) mutationFn, {
    MutationOptions? options,
  }) {
    final mutation = client.useMutation<TData, TVariables>(
      mutationFn,
      options: options,
    );
    _ownedMutations.add(mutation);
    return mutation;
  }

  @override
  void dispose() {
    // Only dispose queries that this widget "owns" (created first)
    // This prevents disposing shared queries used by multiple widgets
    for (final query in _ownedQueries) {
      query.dispose();
    }

    for (final infiniteQuery in _ownedInfiniteQueries) {
      infiniteQuery.dispose();
    }

    // Always dispose mutations since they're typically widget-specific
    for (final mutation in _ownedMutations) {
      mutation.dispose();
    }

    _ownedQueries.clear();
    _ownedInfiniteQueries.clear();
    _ownedMutations.clear();

    super.dispose();
  }
}

/// Simplified mixin for read-only queries (most common case)
/// Even less boilerplate for simple data fetching
///
/// Example:
/// ```dart
/// class PostWidget extends StatefulWidget {
///   @override
///   State<PostWidget> createState() => _PostWidgetState();
/// }
///
/// class _PostWidgetState extends State<PostWidget> with SimpleQueryMixin {
///   late final posts = query<List<Post>, List<dynamic>>(
///     key: ['posts'],
///     fetch: fetchPostsApi,
///     transform: (json) => json.map((e) => Post.fromJson(e)).toList(),
///   );
///
///   @override
///   Widget build(BuildContext context) {
///     return Watch((context) {
///       if (posts.isLoading) return CircularProgressIndicator();
///       return Text('Posts: ${posts.data?.length ?? 0}');
///     });
///   }
/// }
/// ```
mixin SimpleQueryMixin<T extends StatefulWidget> on State<T> {
  /// Global QueryClient instance (singleton)
  QueryClient get client => QueryClient();

  /// Track queries for auto-disposal (only owned queries)
  final Set<Query> _ownedQueries = {};
  final Set<InfiniteQuery> _ownedInfiniteQueries = {};

  /// Simple query creation with minimal syntax
  /// Uses QueryClient defaults for staleDuration and cacheDuration if not specified
  Query<TData, TQueryFnData>
      query<TData extends Object?, TQueryFnData extends Object?>({
    required List<dynamic> key,
    required Future<TQueryFnData> Function() fetch,
    required TData Function(TQueryFnData) transform,
    Duration? staleDuration,
    Duration? cacheDuration,
    bool granularUpdates = false,
  }) {
    final query = client.useQuery<TData, TQueryFnData>(
      key,
      fetch,
      options: QueryOptions(
        staleDuration: staleDuration,
        cacheDuration: cacheDuration,
        transformer: transform,
        granularUpdates: granularUpdates,
      ),
    );

    // Only track as owned if this is a new query
    if (!client.hasQuery(key)) {
      _ownedQueries.add(query);
    }

    return query;
  }

  /// Simple infinite query creation with minimal syntax
  InfiniteQuery<TData, TQueryFnData, TPageParam> infiniteQuery<
      TData extends Object?,
      TQueryFnData extends Object?,
      TPageParam extends Object?>({
    required List<dynamic> key,
    required Future<TQueryFnData> Function(TPageParam pageParam) fetch,
    required TData Function(TQueryFnData) transform,
    required TPageParam? Function(TData lastPage, List<TData> allPages)
        getNextPageParam,
    TPageParam? Function(TData firstPage, List<TData> allPages)?
        getPreviousPageParam,
    TPageParam? initialPageParam,
    Duration? staleDuration,
    Duration? cacheDuration,
  }) {
    final infiniteQuery =
        client.useInfiniteQuery<TData, TQueryFnData, TPageParam>(
      key,
      fetch,
      options: InfiniteQueryOptions(
        staleDuration: staleDuration,
        cacheDuration: cacheDuration,
        transformer: transform,
        getNextPageParam: getNextPageParam,
        getPreviousPageParam: getPreviousPageParam,
        initialPageParam: initialPageParam,
      ),
    );

    // Only track as owned if this is a new query
    if (!client.hasInfiniteQuery(key)) {
      _ownedInfiniteQueries.add(infiniteQuery);
    }

    return infiniteQuery;
  }

  @override
  void dispose() {
    // Only dispose queries that this widget owns
    for (final query in _ownedQueries) {
      query.dispose();
    }
    for (final infiniteQuery in _ownedInfiniteQueries) {
      infiniteQuery.dispose();
    }
    _ownedQueries.clear();
    _ownedInfiniteQueries.clear();

    super.dispose();
  }
}
