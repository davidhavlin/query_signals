import 'package:dio/dio.dart';
import 'package:example/posts/models/post.model.dart';
import 'package:example/comments/models/comment.model.dart';
import 'package:example/shared/service/api.service.dart';
import 'package:query_signals/query_signals.dart';

class PostsStore {
  final _client = QueryClient();

  Future<List<dynamic>> fetchPosts({CancelToken? cancelToken}) async {
    final response = await api.$get('/posts', cancelToken: cancelToken);
    await Future.delayed(Duration(seconds: 2));
    return response['posts'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchPostDetail(
    String postId, {
    CancelToken? cancelToken,
  }) async {
    final response = await api.$get('/posts/$postId', cancelToken: cancelToken);
    await Future.delayed(Duration(seconds: 4));
    return response;
  }

  Future<List<dynamic>> fetchPostComments(
    String postId, {
    CancelToken? cancelToken,
  }) async {
    final response = await api.$get(
      '/posts/$postId/comments',
      cancelToken: cancelToken,
    );
    await Future.delayed(Duration(seconds: 2));
    return response['comments'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> updatePost(
    String postId, {
    String? title,
  }) async {
    final response = await api.$patch(
      '/posts/$postId',
      data: {if (title != null) 'title': title},
    );
    return response;
  }

  // Posts list query
  late final posts = _client.useQuery<List<Post>, List<dynamic>>(
    ['posts'], // Cache key
    fetchPosts, // Pure API function
    options: QueryOptions(
      staleDuration: Duration(minutes: 10), // When to background refresh
      cacheDuration: Duration(hours: 5), // How long to cache
      transformer:
          (jsonList) => // Transform raw JSON to models
              jsonList.map((json) => Post.fromJson(json)).toList(),
    ),
  );

  // Post detail query factory - creates/returns query for specific post
  Query<Post, Map<String, dynamic>> postDetail(String postId) {
    return _client.useQuery<Post, Map<String, dynamic>>(
      ['post-detail', postId], // Unique cache key per post
      ({CancelToken? cancelToken}) => fetchPostDetail(
        postId,
        cancelToken: cancelToken,
      ), // Pure API function
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
      ({CancelToken? cancelToken}) => fetchPostComments(
        postId,
        cancelToken: cancelToken,
      ), // Pure API function
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

  // Update post mutation factory
  Mutation<Post, Map<String, String>> updatePostMutation({
    Function(Post)? onSuccess,
    Function(QueryError)? onError,
  }) {
    return _client.useMutation<Post, Map<String, String>>(
      (params) async {
        final postId = params['postId']!;
        final title = params['title'];
        final response = await updatePost(postId, title: title);
        return Post.fromJson(response);
      },
      options: MutationOptions(
        onSuccess: (updatedPost) {
          // Update the specific post in cache
          _client.setQueryData([
            'post-detail',
            updatedPost.id.toString(),
          ], updatedPost);
          // Invalidate the posts list to refresh it
          _client.invalidateQueries(['posts']);
          onSuccess?.call(updatedPost);
        },
        onError: onError,
      ),
    );
  }
}

final postsStore = PostsStore();
