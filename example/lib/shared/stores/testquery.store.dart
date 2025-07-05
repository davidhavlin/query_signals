import 'package:example/shared/service/api.service.dart';
import 'package:persist_signals/signal_query/models/query_mutation_options.model.dart';
import 'package:persist_signals/signal_query/models/query_options.model.dart';
import 'package:persist_signals/signal_query/query_client.dart';
import 'package:persist_signals/signal_query/query.dart';

// ==================== DATA MODELS ====================

/// Post model - represents a blog post from JSONPlaceholder API
class Post {
  final int id;
  final int userId;
  final String title;
  final String body;

  Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as int,
    userId: json['userId'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
  };
}

// ==================== PURE API FUNCTIONS ====================
// These functions only handle HTTP calls - no data transformation
// This is the React Query way: keep API calls pure and transform in queries

/// Fetch all posts from API (returns raw JSON List)
Future<List<dynamic>> fetchPostsApi() => api.$get('/posts');

/// Fetch single post by ID (returns raw JSON Map)
Future<Map<String, dynamic>> fetchPostApi(int id) => api.$get('/posts/$id');

/// Update post via API (returns raw JSON Map)
final updatePostApi = (int id, Map<String, dynamic> data) =>
    api.$patch('/posts/$id', data: data);

/// Create new post via API (returns raw JSON Map)
final createPostApi = (Map<String, dynamic> data) =>
    api.$post('/posts', data: data);

/// Delete post via API (returns nothing)
final deletePostApi = (int id) => api.$delete('/posts/$id');

// ==================== QUERY STORE ====================

/// Main store containing all queries and mutations for posts
/// This is where React Query magic happens with Flutter signals!
class TestQueryStore {
  final _client = QueryClient();

  // ==================== QUERIES ====================

  /// All posts query with caching and background refresh
  ///
  /// Features:
  /// - Transforms raw JSON to List<Post> automatically
  /// - Caches for 1 hour, considers stale after 30 minutes
  /// - Background refetch when stale
  /// - Persists across app restarts
  ///
  /// Usage in widget:
  /// ```dart
  /// Watch((context) {
  ///   if (store.posts.isLoading) return CircularProgressIndicator();
  ///   final posts = store.posts.data ?? [];
  ///   return ListView.builder(...);
  /// })
  /// ```
  late final posts = _client.useQuery<List<Post>, List<dynamic>>(
    ['posts'], // Cache key
    fetchPostsApi, // Raw API call
    options: QueryOptions(
      staleDuration: Duration(minutes: 30), // When to background refresh
      cacheDuration: Duration(hours: 1), // How long to keep in cache
      transformer:
          (jsonList) => // Transform raw JSON to models
              jsonList.map((json) => Post.fromJson(json)).toList(),
    ),
  );

  /// Individual post query - great for detail pages
  /// Each post gets its own cache entry with key ['posts', id]
  Query<Post, Map<String, dynamic>> getPost(int id) =>
      _client.useQuery<Post, Map<String, dynamic>>(
        ['posts', id], // Hierarchical cache key
        () => fetchPostApi(id), // API call for specific post
        options: QueryOptions(
          staleDuration: Duration(minutes: 15), // Refresh more frequently
          transformer: (json) => Post.fromJson(json), // JSON to Post
        ),
      );

  // ==================== MUTATIONS ====================

  /// Update post mutation with optimistic updates
  ///
  /// When you call `updatePost.mutate({...})`:
  /// 1. UI updates immediately (optimistic)
  /// 2. API call happens in background
  /// 3. On success: cache stays updated
  /// 4. On error: reverts to previous state
  late final updatePost = _client.useMutation<Post, Map<String, dynamic>>(
    (variables) async {
      final id = variables['id'] as int;
      final data = Map<String, dynamic>.from(variables)..remove('id');
      final rawResult = await updatePostApi(id, data);
      return Post.fromJson(rawResult); // Transform response
    },
    options: MutationOptions(
      onSuccess: (updatedPost) {
        // Optimistic update: immediately update posts list
        final currentPosts = posts.data;
        if (currentPosts != null) {
          final updatedPosts = currentPosts.map((post) {
            return post.id == updatedPost.id ? updatedPost : post;
          }).toList();
          _client.setQueryData(['posts'], updatedPosts);
        }

        // Also update individual post cache
        _client.setQueryData(['posts', updatedPost.id], updatedPost);
      },
    ),
  );

  /// Create new post mutation
  late final createPost = _client.useMutation<Post, Map<String, dynamic>>(
    (data) async {
      final rawResult = await createPostApi(data);
      return Post.fromJson(rawResult);
    },
    options: MutationOptions(
      onSuccess: (newPost) {
        // Add new post to the list immediately
        final currentPosts = posts.data;
        if (currentPosts != null) {
          final updatedPosts = [...currentPosts, newPost];
          _client.setQueryData(['posts'], updatedPosts);
        }
      },
    ),
  );

  /// Delete post mutation
  late final deletePost = _client.useMutation<int, int>(
    (postId) async {
      await deletePostApi(postId);
      return postId; // Return ID for success callback
    },
    options: MutationOptions(
      onSuccess: (deletedId) {
        // Remove post from list immediately
        final currentPosts = posts.data;
        if (currentPosts != null) {
          final updatedPosts = currentPosts
              .where((post) => post.id != deletedId)
              .toList();
          _client.setQueryData(['posts'], updatedPosts);
        }

        // Remove individual post from cache
        _client.removeQueries(['posts', deletedId]);
      },
    ),
  );

  // ==================== UTILITY METHODS ====================

  /// Manually refetch all posts (e.g., for pull-to-refresh)
  void refetchPosts() => posts.refetch();

  /// Mark all post queries as stale and refetch them
  /// Useful after major data changes
  void invalidatePosts() => _client.invalidateQueries(['posts']);

  /// Preload a specific post (great for predictive loading)
  /// Call this when user hovers over a post link
  void prefetchPost(int id) =>
      _client.prefetchQuery<Post, Map<String, dynamic>>(
        ['posts', id],
        () => fetchPostApi(id),
        options: QueryOptions(transformer: (json) => Post.fromJson(json)),
      );

  // ==================== HYDRATION ====================

  /// Wait for cached posts to load before showing UI
  /// Call this in main() to avoid loading flicker on app start
  Future<void> waitForHydration() => posts.waitForHydration();

  /// Dispose all queries and mutations to prevent memory leaks
  /// Call this when the store is no longer needed
  void dispose() {
    posts.dispose();
    updatePost.dispose();
    createPost.dispose();
    deletePost.dispose();
  }
}
