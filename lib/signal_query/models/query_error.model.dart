enum QueryErrorType { network, timeout, parsing, server, unknown }

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
