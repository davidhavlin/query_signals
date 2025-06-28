import 'package:example/posts/models/post.model.dart';

/// Represents a page of posts from the dummyjson.com API
/// Used with InfiniteQuery for paginated data fetching
class PostsPage {
  final List<Post> posts;
  final int total;
  final int skip;
  final int limit;

  PostsPage({
    required this.posts,
    required this.total,
    required this.skip,
    required this.limit,
  });

  /// Whether there are more posts to fetch
  bool get hasMore => skip + posts.length < total;

  /// Next skip value for pagination
  int get nextSkip => skip + limit;

  factory PostsPage.fromJson(Map<String, dynamic> json) {
    return PostsPage(
      posts: (json['posts'] as List<dynamic>)
          .map((postJson) => Post.fromJson(postJson))
          .toList(),
      total: json['total'] ?? 0,
      skip: json['skip'] ?? 0,
      limit: json['limit'] ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
    'posts': posts.map((post) => post.toJson()).toList(),
    'total': total,
    'skip': skip,
    'limit': limit,
  };
}
