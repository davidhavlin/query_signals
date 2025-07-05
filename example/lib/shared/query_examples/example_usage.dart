import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import '../stores/testquery.store.dart';

class PostsExample extends StatefulWidget {
  const PostsExample({super.key});

  @override
  _PostsExampleState createState() => _PostsExampleState();
}

class _PostsExampleState extends State<PostsExample> {
  final store = TestQueryStore();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('React Query for Flutter')),
      body: Column(
        children: [
          // Posts List
          Expanded(
            child: Watch((context) {
              if (store.posts.isLoading) {
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

              return RefreshIndicator(
                onRefresh: () => store.posts.refetch(),
                child: ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(post.title),
                        subtitle: Text(post.body),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit button
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _editPost(post),
                            ),
                            // Delete button
                            Watch((context) {
                              final isDeleting = store.deletePost.isLoading;
                              return isDeleting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.delete),
                                      onPressed: () =>
                                          store.deletePost.mutate(post.id),
                                    );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),

          // Status indicators
          Padding(
            padding: EdgeInsets.all(16),
            child: Watch((context) {
              return Column(
                children: [
                  if (store.posts.isStale)
                    Text(
                      'Data is stale',
                      style: TextStyle(color: Colors.orange),
                    ),
                  if (store.posts.lastFetched != null)
                    Text(
                      'Last fetched: ${store.posts.lastFetched}',
                      style: TextStyle(fontSize: 12),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: store.refetchPosts,
                        child: Text('Refetch'),
                      ),
                      ElevatedButton(
                        onPressed: store.invalidatePosts,
                        child: Text('Invalidate'),
                      ),
                      ElevatedButton(
                        onPressed: _createPost,
                        child: Text('Create Post'),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _editPost(Post post) {
    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: post,
        onSave: (title, body) {
          store.updatePost.mutate({
            'id': post.id,
            'title': title,
            'body': body,
            'userId': post.userId,
          });
        },
      ),
    );
  }

  void _createPost() {
    showDialog(
      context: context,
      builder: (context) => CreatePostDialog(
        onSave: (title, body) {
          store.createPost.mutate({'title': title, 'body': body, 'userId': 1});
        },
      ),
    );
  }
}

class EditPostDialog extends StatefulWidget {
  final Post post;
  final Function(String title, String body) onSave;

  EditPostDialog({super.key, required this.post, required this.onSave});

  @override
  _EditPostDialogState createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late TextEditingController titleController;
  late TextEditingController bodyController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.post.title);
    bodyController = TextEditingController(text: widget.post.body);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: bodyController,
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
        ElevatedButton(
          onPressed: () {
            widget.onSave(titleController.text, bodyController.text);
            Navigator.pop(context);
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}

class CreatePostDialog extends StatefulWidget {
  final Function(String title, String body) onSave;

  CreatePostDialog({super.key, required this.onSave});

  @override
  _CreatePostDialogState createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: bodyController,
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
        ElevatedButton(
          onPressed: () {
            widget.onSave(titleController.text, bodyController.text);
            Navigator.pop(context);
          },
          child: Text('Create'),
        ),
      ],
    );
  }
}
