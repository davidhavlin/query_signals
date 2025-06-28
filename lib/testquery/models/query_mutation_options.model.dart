import 'package:persist_signals/testquery/models/query_error.model.dart';

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
