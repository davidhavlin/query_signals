import 'package:dio/dio.dart';

/// Represents a function that fetches data and optionally accepts a cancel token
typedef QueryFn<TQueryFnData extends Object?> = Future<TQueryFnData> Function({
  CancelToken? cancelToken,
});
