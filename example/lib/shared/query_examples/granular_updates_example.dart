import 'package:flutter/material.dart';
import 'package:persist_signals/storage/storable.types.dart';
import 'package:persist_signals/signal_query/models/query_mutation_options.model.dart';
import 'package:persist_signals/signal_query/models/query_options.model.dart';
import 'package:signals/signals_flutter.dart';
import 'package:persist_signals/signal_query/query_client.dart';

// ==================== MODEL WITH HasId ====================

/// Post model that implements HasId for efficient granular storage
class Post implements HasId {
  @override
  final String id;
  final int userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final int likesCount;

  Post({
    required int id,
    required this.userId,
    required this.title,
    required this.body,
    DateTime? createdAt,
    this.likesCount = 0,
  }) : id = id.toString(),
       createdAt = createdAt ?? DateTime.now();

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as int,
    userId: json['userId'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    likesCount: json['likesCount'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': int.parse(id),
    'userId': userId,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'likesCount': likesCount,
  };

  // Helper method for updating specific fields
  Post copyWith({String? title, String? body, int? likesCount}) => Post(
    id: int.parse(id),
    userId: userId,
    title: title ?? this.title,
    body: body ?? this.body,
    createdAt: createdAt,
    likesCount: likesCount ?? this.likesCount,
  );
}

// ==================== API FUNCTIONS ====================

/// Simulate fetching 1000+ posts from API
Future<List<dynamic>> fetchManyPostsApi() async {
  await Future.delayed(Duration(seconds: 2)); // Simulate network delay

  // Generate many posts for testing
  return List.generate(
    1000,
    (index) => {
      'id': index + 1,
      'userId': (index % 10) + 1,
      'title': 'Post ${index + 1}: Lorem ipsum dolor sit amet',
      'body':
          'This is the body content of post ${index + 1}. Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      'createdAt': DateTime.now()
          .subtract(Duration(hours: index))
          .toIso8601String(),
      'likesCount': index % 100,
    },
  );
}

/// Simulate updating a post
Future<Map<String, dynamic>> updatePostApi(
  int id,
  Map<String, dynamic> data,
) async {
  await Future.delayed(Duration(milliseconds: 500));
  return {
    'id': id,
    'userId': data['userId'],
    'title': data['title'],
    'body': data['body'],
    'createdAt': data['createdAt'],
    'likesCount': data['likesCount'],
  };
}

/// Simulate creating a post
Future<Map<String, dynamic>> createPostApi(Map<String, dynamic> data) async {
  await Future.delayed(Duration(milliseconds: 500));
  return {
    ...data,
    'id': DateTime.now().millisecondsSinceEpoch, // Generate new ID
    'createdAt': DateTime.now().toIso8601String(),
  };
}

/// Simulate deleting a post
Future<void> deletePostApi(int id) async {
  await Future.delayed(Duration(milliseconds: 300));
  // Just simulate the delay
}

// ==================== STORE WITH GRANULAR UPDATES ====================

class GranularPostsStore {
  final _client = QueryClient();

  /// Large posts list with granular updates enabled
  /// Each post update only touches 1 record in storage instead of saving 1000+ items!
  late final posts = _client.useQuery<List<Post>, List<dynamic>>(
    ['posts'],
    fetchManyPostsApi,
    options: QueryOptions(
      granularUpdates: true, // 🔥 Enable efficient storage!
      staleDuration: Duration(minutes: 10),
      cacheDuration: Duration(hours: 2),
      transformer: (jsonList) =>
          (jsonList as List).map((json) => Post.fromJson(json)).toList(),
    ),
  );

  /// Update post mutation with granular storage optimization
  late final updatePost = _client.useMutation<Post, Map<String, dynamic>>(
    (variables) async {
      final id = variables['id'] as int;
      final data = Map<String, dynamic>.from(variables)..remove('id');
      final result = await updatePostApi(id, data);
      return Post.fromJson(result);
    },
    options: MutationOptions(
      onSuccess: (updatedPost) {
        // 🔥 GRANULAR UPDATE: Only saves the changed post to storage!
        // Instead of saving all 1000+ posts, saves just 1 record
        _client.updateQueryListItem<List<Post>, Post>(
          ['posts'],
          updatedPost,
          itemId: (post) => post.id,
        );

        print(
          '✅ Updated post ${updatedPost.id} - only 1 record saved to storage!',
        );
      },
    ),
  );

  /// Create post mutation
  late final createPost = _client.useMutation<Post, Map<String, dynamic>>(
    (data) async {
      final result = await createPostApi(data);
      return Post.fromJson(result);
    },
    options: MutationOptions(
      onSuccess: (newPost) {
        // 🔥 GRANULAR ADD: Only saves the new post to storage!
        _client.addQueryListItem<List<Post>, Post>(['posts'], newPost);
        print('✅ Added post ${newPost.id} - only 1 record added to storage!');
      },
    ),
  );

  /// Delete post mutation
  late final deletePost = _client.useMutation<int, int>(
    (postId) async {
      await deletePostApi(postId);
      return postId;
    },
    options: MutationOptions(
      onSuccess: (deletedId) {
        // 🔥 GRANULAR REMOVE: Only deletes 1 record from storage!
        _client.removeQueryListItem<List<Post>, Post>(
          ['posts'],
          deletedId.toString(),
          (post) => post.id,
        );
        print(
          '✅ Deleted post $deletedId - only 1 record removed from storage!',
        );
      },
    ),
  );

  /// Like a post (increment likes count) - super fast update!
  void likePost(Post post) {
    final updatedPost = post.copyWith(likesCount: post.likesCount + 1);

    // Optimistic update using granular storage
    _client.updateQueryListItem<List<Post>, Post>(
      ['posts'],
      updatedPost,
      itemId: (p) => p.id,
    );

    // Then sync with server (in real app)
    updatePost.mutate({
      'id': int.parse(post.id),
      'userId': post.userId,
      'title': post.title,
      'body': post.body,
      'createdAt': post.createdAt.toIso8601String(),
      'likesCount': updatedPost.likesCount,
    });
  }

  void dispose() {
    posts.dispose();
    updatePost.dispose();
    createPost.dispose();
    deletePost.dispose();
  }
}

// ==================== UI EXAMPLE ====================

class GranularUpdatesExample extends StatefulWidget {
  const GranularUpdatesExample({super.key});

  @override
  State<GranularUpdatesExample> createState() => _GranularUpdatesExampleState();
}

class _GranularUpdatesExampleState extends State<GranularUpdatesExample> {
  final store = GranularPostsStore();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    store.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Granular Updates Demo'),
            Text(
              '1000+ posts, efficient storage',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Watch((context) {
            return IconButton(
              icon: Icon(store.posts.isLoading ? Icons.sync : Icons.refresh),
              onPressed: store.posts.isLoading
                  ? null
                  : () => store.posts.refetch(),
            );
          }),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Watch((context) {
              final posts = store.posts.data ?? [];
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCard('Posts', posts.length.toString()),
                  _StatCard(
                    'Total Likes',
                    posts.fold(0, (sum, p) => sum + p.likesCount).toString(),
                  ),
                  _StatCard(
                    'Status',
                    store.posts.isLoading ? 'Loading' : 'Ready',
                  ),
                ],
              );
            }),
          ),

          // Posts list
          Expanded(
            child: Watch((context) {
              if (store.posts.isLoading && store.posts.data == null) {
                return Center(child: CircularProgressIndicator());
              }

              if (store.posts.isError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      Text(
                        'Error: ${store.posts.error?.message ?? "Unknown error"}',
                      ),
                      if (store.posts.error?.type != null)
                        Text('Type: ${store.posts.error!.type.name}'),
                      ElevatedButton(
                        onPressed: () => store.posts.refetch(),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final posts = store.posts.data ?? [];
              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(
                        post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        post.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like button with count
                          InkWell(
                            onTap: () => store.likePost(post),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text('${post.likesCount}'),
                                ],
                              ),
                            ),
                          ),

                          // Delete button
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.red.shade300,
                            ),
                            onPressed: () =>
                                store.deletePost.mutate(int.parse(post.id)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        icon: Icon(Icons.add),
        label: Text('Add Post'),
      ),
    );
  }

  Widget _StatCard(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(labelText: 'Body'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          Watch((context) {
            return ElevatedButton(
              onPressed: store.createPost.isLoading
                  ? null
                  : () {
                      store.createPost.mutate({
                        'userId': 1,
                        'title': _titleController.text,
                        'body': _bodyController.text,
                      });
                      _titleController.clear();
                      _bodyController.clear();
                      Navigator.pop(context);
                    },
              child: store.createPost.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Create'),
            );
          }),
        ],
      ),
    );
  }
}

// ==================== COMPARISON DEMO ====================

/// Widget showing performance difference between granular and regular updates
class PerformanceComparisonDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Performance Comparison')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Performance Comparison',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            _ComparisonCard(
              title: 'Without Granular Updates',
              description: 'granularUpdates: false (default)',
              performance: [
                '❌ Update 1 post → Save entire 1000-item list to storage',
                '❌ Add 1 post → Save entire 1001-item list to storage',
                '❌ Delete 1 post → Save entire 999-item list to storage',
                '⚠️  Large memory usage and slow storage operations',
              ],
              color: Colors.red.shade50,
            ),

            SizedBox(height: 16),

            _ComparisonCard(
              title: 'With Granular Updates',
              description: 'granularUpdates: true',
              performance: [
                '✅ Update 1 post → Save only 1 record to storage',
                '✅ Add 1 post → Save only 1 new record to storage',
                '✅ Delete 1 post → Delete only 1 record from storage',
                '🚀 1000x faster storage operations for large lists!',
              ],
              color: Colors.green.shade50,
            ),

            SizedBox(height: 24),

            Text(
              'Requirements for Granular Updates:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              '• Model must implement HasId interface\n'
              '• Model must have toJson() method\n'
              '• Enable granularUpdates: true in QueryOptions\n'
              '• Use provided granular update methods',
            ),
          ],
        ),
      ),
    );
  }

  Widget _ComparisonCard({
    required String title,
    required String description,
    required List<String> performance,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(description, style: TextStyle(color: Colors.grey.shade600)),
          SizedBox(height: 12),
          ...performance.map(
            (item) =>
                Padding(padding: EdgeInsets.only(bottom: 4), child: Text(item)),
          ),
        ],
      ),
    );
  }
}
