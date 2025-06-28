import 'package:example/posts/models/post.model.dart';
import 'package:example/comments/models/comment.model.dart';
import 'package:example/shared/service/api.service.dart';
import 'package:persist_signals/testquery/query_client.dart';
import 'package:persist_signals/testquery/query.dart';
import 'package:persist_signals/testquery/mutation.dart';
import 'package:persist_signals/testquery/types/query_types.dart';

class PostsStore {
  final _client = QueryClient();

  Future<List<dynamic>> fetchPosts() async {
    print('CALL fetchPosts');
    await Future.delayed(Duration(seconds: 2));
    final response = await api.$get('/posts');
    return response['posts'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchPostDetail(String postId) async {
    print('CALL fetchPostDetail: $postId');
    final response = await api.$get('/posts/$postId');
    return response;
  }

  Future<List<dynamic>> fetchPostComments(String postId) async {
    print('CALL fetchPostComments: $postId');
    final response = await api.$get('/posts/$postId/comments');
    return response['comments'] as List<dynamic>;
  }

  // Posts list query
  late final posts = _client.useQuery<List<Post>, List<dynamic>>(
    ['posts'], // Cache key
    fetchPosts, // Pure API function
    options: QueryOptions(
      staleDuration: Duration(minutes: 1), // When to background refresh
      cacheDuration: Duration(minutes: 5), // How long to cache
      transformer:
          (jsonList) => // Transform raw JSON to models
              jsonList.map((json) => Post.fromJson(json)).toList(),
    ),
  );

  // Post detail query factory - creates/returns query for specific post
  Query<Post, Map<String, dynamic>> postDetail(String postId) {
    return _client.useQuery<Post, Map<String, dynamic>>(
      ['post-detail', postId], // Unique cache key per post
      () => fetchPostDetail(postId), // Pure API function
      options: QueryOptions(
        staleDuration: Duration(minutes: 15), // Post details stay fresh longer
        cacheDuration: Duration(hours: 1), // Cache longer since they're heavier
        transformer: (json) => Post.fromJson(json), // Transform to model
      ),
    );
  }

  // Post comments query factory - creates/returns query for specific post's comments
  Query<List<Comment>, List<dynamic>> postComments(String postId) {
    return _client.useQuery<List<Comment>, List<dynamic>>(
      ['post-comments', postId], // Unique cache key per post
      () => fetchPostComments(postId), // Pure API function
      options: QueryOptions(
        staleDuration: Duration(minutes: 5), // Comments refresh more frequently
        cacheDuration: Duration(minutes: 30), // Cache for reasonable time
        transformer:
            (jsonList) => // Transform raw JSON to models
                jsonList.map((json) => Comment.fromJson(json)).toList(),
      ),
    );
  }

  // Delete post mutation factory
  Mutation<void, String> deletePost({
    Function()? onSuccess,
    Function(QueryError)? onError,
  }) {
    return _client.useMutation<void, String>(
      (postId) async {
        await api.$delete('/posts/$postId');
      },
      options: MutationOptions(
        onSuccess: (_) {
          // Invalidate both lists and individual post caches
          _client.invalidateQueries(['posts']);
          _client.invalidateQueries(['post-detail']);
          onSuccess?.call();
        },
        onError: onError,
      ),
    );
  }
}

final postsStore = PostsStore();
