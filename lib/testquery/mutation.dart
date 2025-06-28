import 'package:persist_signals/testquery/models/query_error.model.dart';
import 'package:persist_signals/testquery/models/query_mutation_options.model.dart';
import 'package:signals/signals_flutter.dart';
import 'enums/query_status.enum.dart';
import 'query_client.dart';

class Mutation<TData extends Object?, TVariables extends Object?> {
  final String mutationKey; // Track this mutation for disposal
  final Future<TData> Function(TVariables variables) mutationFn;
  final MutationOptions options;
  final QueryClient _client;

  late final Signal<QueryStatus> _status;
  late final Signal<TData?> _data;
  late final Signal<QueryError?> _error;

  // Memoized computed signals for performance
  late final FlutterComputed<bool> _isLoadingSignal;
  late final FlutterComputed<bool> _isSuccessSignal;
  late final FlutterComputed<bool> _isErrorSignal;

  Mutation({
    required this.mutationKey,
    required this.mutationFn,
    required this.options,
    required QueryClient client,
  }) : _client = client {
    _status = signal(QueryStatus.idle);
    _data = signal<TData?>(null);
    _error = signal<QueryError?>(null);

    // Initialize memoized computed signals
    _isLoadingSignal = computed(() => _status.value == QueryStatus.loading);
    _isSuccessSignal = computed(() => _status.value == QueryStatus.success);
    _isErrorSignal = computed(() => _status.value == QueryStatus.error);
  }

  // Reactive getters
  QueryStatus get status => _status.value;
  TData? get data => _data.value;
  QueryError? get error => _error.value;
  bool get isLoading => _status.value == QueryStatus.loading;
  bool get isSuccess => _status.value == QueryStatus.success;
  bool get isError => _status.value == QueryStatus.error;
  bool get isIdle => _status.value == QueryStatus.idle;

  // For Watch widget - return memoized computed signals
  Signal<QueryStatus> get statusSignal => _status;
  Signal<TData?> get dataSignal => _data;
  Signal<QueryError?> get errorSignal => _error;
  FlutterComputed<bool> get isLoadingSignal => _isLoadingSignal;
  FlutterComputed<bool> get isSuccessSignal => _isSuccessSignal;
  FlutterComputed<bool> get isErrorSignal => _isErrorSignal;

  Future<TData?> mutate(TVariables variables) async {
    try {
      _status.value = QueryStatus.loading;
      _error.value = null;

      final result = await mutationFn(variables);

      _data.value = result;
      _status.value = QueryStatus.success;

      options.onSuccess?.call(result);
      options.onSettled?.call();

      return result;
    } catch (e, stackTrace) {
      // Create proper QueryError from exception
      final queryError = e is QueryError
          ? e
          : QueryError(e.toString(), QueryErrorType.unknown, e, stackTrace);

      _error.value = queryError;
      _status.value = QueryStatus.error;

      options.onError?.call(queryError);
      options.onSettled?.call();

      return null;
    }
  }

  void reset() {
    _status.value = QueryStatus.idle;
    _data.value = null;
    _error.value = null;
  }

  /// Clean up mutation when no longer needed
  /// Disposes all signals to prevent memory leaks
  void dispose() {
    // Remove this mutation from the client first
    _client.disposeMutation(mutationKey);

    // Dispose all signals
    _status.dispose();
    _data.dispose();
    _error.dispose();

    // Dispose memoized computed signals
    _isLoadingSignal.dispose();
    _isSuccessSignal.dispose();
    _isErrorSignal.dispose();
  }
}
