import 'package:example/posts/components/post_card.dart';
import 'package:example/posts/stores/posts.store.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

class PostsRoute extends StatefulWidget {
  const PostsRoute({super.key});

  @override
  State<PostsRoute> createState() => _PostsRouteState();
}

class _PostsRouteState extends State<PostsRoute> {
  @override
  void initState() {
    super.initState();
    postsStore.posts.sync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Watch((context) {
          final posts = postsStore.posts;

          if (posts.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (posts.isError) {
            return const Center(child: Text('Error showing posts'));
          }
          final items = posts.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return PostCard(post: item);
            },
          );
        }),
      ),
    );
  }
}
