/// Data structure for infinite queries - holds all pages and page parameters
/// Similar to React Query's InfiniteData structure
class InfiniteData<TData> {
  final List<TData> pages;
  final List<dynamic> pageParams;

  const InfiniteData({required this.pages, required this.pageParams});

  /// Get flattened data from all pages
  /// Override this in subclasses if pages need custom flattening logic
  List<T> flatMap<T>(List<T> Function(TData page) mapper) {
    return pages.expand(mapper).toList();
  }

  /// Create new InfiniteData with additional page
  InfiniteData<TData> addPage(TData page, dynamic pageParam) {
    return InfiniteData(
      pages: [...pages, page],
      pageParams: [...pageParams, pageParam],
    );
  }

  /// Create new InfiniteData with replaced page at index
  InfiniteData<TData> replacePage(int index, TData page) {
    final newPages = [...pages];
    newPages[index] = page;
    return InfiniteData(pages: newPages, pageParams: pageParams);
  }

  /// Reset to empty state
  static InfiniteData<TData> empty<TData>() {
    return const InfiniteData(pages: [], pageParams: []);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InfiniteData<TData> &&
        pages.length == other.pages.length &&
        pageParams.length == other.pageParams.length;
  }

  @override
  int get hashCode => Object.hash(pages, pageParams);

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() => {'pages': pages, 'pageParams': pageParams};

  /// Create from cached JSON
  static InfiniteData<TData> fromJson<TData>(
    Map<String, dynamic> json,
    TData Function(dynamic) pageFromJson,
  ) {
    return InfiniteData<TData>(
      pages: (json['pages'] as List).map(pageFromJson).toList(),
      pageParams: json['pageParams'] as List,
    );
  }
}
