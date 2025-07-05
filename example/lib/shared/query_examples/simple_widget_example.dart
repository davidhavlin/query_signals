import 'package:example/shared/stores/testquery.store.dart';
import 'package:persist_signals/signal_query/mixins/query_mixin.dart';
import 'package:persist_signals/signal_query/models/query_mutation_options.model.dart';
import 'package:persist_signals/signal_query/models/query_options.model.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

// ==================== SIMPLE USAGE EXAMPLES ====================

/// Example 1: Using QueryMixin for auto-disposal
/// No manual disposal needed!
class SimpleWidgetExample extends StatefulWidget {
  const SimpleWidgetExample({super.key});

  @override
  State<SimpleWidgetExample> createState() => _SimpleWidgetExampleState();
}

class _SimpleWidgetExampleState extends State<SimpleWidgetExample>
    with QueryMixin {
  final tempId = 1;

  // Query is automatically tracked and disposed when widget is disposed
  late final post = useQuery<Post, Map<String, dynamic>>(
    ['posts', tempId],
    () => fetchPostApi(tempId),
    options: QueryOptions(
      staleDuration: Duration(minutes: 15),
      transformer: (json) => Post.fromJson(json),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      if (post.isLoading) {
        return const CircularProgressIndicator();
      }
      if (post.isError) {
        return Text('Error: ${post.error ?? 'Unknown error'}');
      }

      return Text(post.data?.title ?? 'No data');
    });
  }
}

/// Example 2: Even simpler with SimpleQueryMixin
/// Minimal boilerplate for common cases
class EvenSimplerExample extends StatefulWidget {
  const EvenSimplerExample({super.key});

  @override
  State<EvenSimplerExample> createState() => _EvenSimplerExampleState();
}

class _EvenSimplerExampleState extends State<EvenSimplerExample>
    with SimpleQueryMixin {
  // Super clean syntax with automatic disposal
  late final posts = query<List<Post>, List<dynamic>>(
    key: ['posts'],
    fetch: fetchPostsApi,
    transform: (json) => (json as List).map((e) => Post.fromJson(e)).toList(),
    staleDuration: Duration(minutes: 10),
  );

  late final singlePost = query<Post, Map<String, dynamic>>(
    key: ['posts', 5],
    fetch: () => fetchPostApi(5),
    transform: (json) => Post.fromJson(json),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Posts list
        Watch((context) {
          if (posts.isLoading) return CircularProgressIndicator();
          return Text('Posts count: ${posts.data?.length ?? 0}');
        }),

        // Single post
        Watch((context) {
          if (singlePost.isLoading) return Text('Loading post...');
          return Text('Post: ${singlePost.data?.title ?? 'None'}');
        }),
      ],
    );
  }
}

/// Example 3: With mutations using QueryMixin
class MutationExample extends StatefulWidget {
  const MutationExample({super.key});

  @override
  State<MutationExample> createState() => _MutationExampleState();
}

class _MutationExampleState extends State<MutationExample> with QueryMixin {
  // Queries and mutations auto-disposed
  late final posts = useQuery<List<Post>, List<dynamic>>(
    ['posts'],
    fetchPostsApi,
    options: QueryOptions(
      transformer: (json) => json.map((e) => Post.fromJson(e)).toList(),
    ),
  );

  late final createPost = useMutation<Post, Map<String, dynamic>>(
    (data) async {
      final result = await createPostApi(data);
      return Post.fromJson(result);
    },
    options: MutationOptions(
      onSuccess: (newPost) {
        // Optimistic update
        final currentPosts = posts.data ?? [];
        final updatedPosts = [...currentPosts, newPost];
        client.setQueryData(['posts'], updatedPosts);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Watch((context) {
          if (posts.isLoading) return CircularProgressIndicator();
          return Text('Posts: ${posts.data?.length ?? 0}');
        }),
        ElevatedButton(
          onPressed: () => createPost.mutate({
            'title': 'New Post ${DateTime.now().millisecondsSinceEpoch}',
            'body': 'Created from widget',
            'userId': 1,
          }),
          child: Watch((context) {
            if (createPost.isLoading) return Text('Creating...');
            return Text('Create Post');
          }),
        ),
      ],
    );
  }
}
