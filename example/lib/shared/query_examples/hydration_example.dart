import 'package:example/shared/service/storage.service.dart';
import 'package:example/shared/stores/testquery.store.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:persist_signals/signal_query/client/query_client.dart';
import '../stores/app.store.dart';

// ==================== HYDRATION EXAMPLE ====================

/// Example showing how to preload cached data before showing UI
/// This eliminates the brief loading flicker on app start

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Initialize your storage system
  // (Replace with your actual persist_signals setup)
  final storage = await StorageService().init();

  // Step 2: Initialize QueryClient
  await QueryClient().init(storage: storage);

  // Step 3: Create your stores BEFORE runApp
  // This triggers query creation and starts loading cached data
  final postStore = TestQueryStore();

  // Step 4: Wait for cached data to load
  // This prevents loading flicker when app first shows
  await postStore.waitForHydration();

  // Alternative: Wait for specific queries
  // await QueryClient().waitForQueriesHydration([
  //   ['posts'],
  //   ['user', userId],
  // ]);

  // Alternative: Wait for ALL queries to hydrate
  // await QueryClient().waitForHydration();

  runApp(MyApp(postStore: postStore));
}

class MyApp extends StatelessWidget {
  final TestQueryStore postStore;

  const MyApp({required this.postStore});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'React Query Flutter',
      home: PostsPage(store: postStore),
    );
  }
}

class PostsPage extends StatelessWidget {
  final TestQueryStore store;

  const PostsPage({required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Posts')),
      body: PostsList(store: store),
    );
  }
}

class PostsList extends StatelessWidget {
  final TestQueryStore store;

  const PostsList({required this.store});

  @override
  Widget build(BuildContext context) {
    // No loading state shown on first render thanks to hydration!
    // Cached data is already loaded and available

    return Watch((context) {
      // This will only show loading during manual refetch or initial fetch
      // (not on app startup if cached data exists)
      if (store.posts.isLoading && store.posts.data == null) {
        return Center(child: CircularProgressIndicator());
      }

      if (store.posts.isError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${store.posts.error}'),
              ElevatedButton(
                onPressed: () => store.posts.refetch(),
                child: Text('Retry'),
              ),
            ],
          ),
        );
      }

      final posts = store.posts.data ?? [];

      return Column(
        children: [
          // Status indicator
          if (store.posts.isLoading)
            LinearProgressIndicator(), // Shows during background refresh

          if (store.posts.isStale)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(8),
              color: Colors.orange.shade100,
              child: Text(
                'Data is stale - refreshing in background',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),

          // Posts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => store.posts.refetch(),
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return ListTile(
                    title: Text(post.title),
                    subtitle: Text(post.body),
                    onTap: () => _showPostDetails(context, post.id),
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showPostDetails(BuildContext context, int postId) {
    // Prefetch post data when navigating (optional optimization)
    store.prefetchPost(postId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(store: store, postId: postId),
      ),
    );
  }
}

class PostDetailPage extends StatelessWidget {
  final TestQueryStore store;
  final int postId;

  const PostDetailPage({required this.store, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Post Details')),
      body: Watch((context) {
        final postQuery = store.getPost(postId);

        if (postQuery.isLoading && postQuery.data == null) {
          return Center(child: CircularProgressIndicator());
        }

        if (postQuery.isError) {
          return Center(child: Text('Error: ${postQuery.error}'));
        }

        final post = postQuery.data;
        if (post == null) {
          return Center(child: Text('Post not found'));
        }

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 16),
              Text(post.body),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _editPost(context, post),
                child: Text('Edit Post'),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _editPost(BuildContext context, Post post) {
    // Example optimistic update
    store.updatePost.mutate({
      'id': post.id,
      'title': '${post.title} (Updated)',
      'body': post.body,
      'userId': post.userId,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Post updated!')));
  }
}
