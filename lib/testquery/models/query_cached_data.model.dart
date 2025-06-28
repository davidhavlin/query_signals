/// Helper class to hold cached data with its timestamp
class QueryCachedData<T> {
  final T data;
  final DateTime time;

  QueryCachedData(this.data, this.time);
}
