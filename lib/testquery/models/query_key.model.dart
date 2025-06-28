/// Unique identifier for queries - used for caching and invalidation
/// Example: QueryKey(['posts']) or QueryKey(['posts', userId])
class QueryKey {
  final List<dynamic> key;
  int? _cachedHash; // Cache hash for performance

  QueryKey(this.key);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! QueryKey) return false;
    if (key.length != other.key.length) return false;
    for (int i = 0; i < key.length; i++) {
      if (key[i] != other.key[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _cachedHash ??= Object.hashAll(key);

  @override
  String toString() => key.join('_');
}
