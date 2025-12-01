import 'package:dio/dio.dart';

class QueryFnContext {
  final CancelToken cancelToken;
  final List<dynamic> queryKey;

  QueryFnContext({required this.cancelToken, required this.queryKey});
}

typedef QueryFn<T> = Future<T> Function(QueryFnContext ctx);
