import 'package:example/comments/components/comment_card.dart';
import 'package:example/posts/models/post.model.dart';
import 'package:example/comments/models/comment.model.dart';
import 'package:example/posts/stores/posts.store.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

class PostDetailRoute extends StatefulWidget {
  final String postId;
  const PostDetailRoute({super.key, required this.postId});

  @override
  State<PostDetailRoute> createState() => _PostDetailRouteState();
}

class _PostDetailRouteState extends State<PostDetailRoute> {
  // Get queries from store - cleaner architecture
  late final postDetail = postsStore.postDetail(widget.postId);
  late final postComments = postsStore.postComments(widget.postId);
  late final deleteMutation = postsStore.deletePost(
    onSuccess: () {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Post deleted successfully')));
    },
    onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: ${error.message}'),
          backgroundColor: Colors.red,
        ),
      );
    },
  );

  void _handleEdit() {
    // TODO: Navigate to edit screen
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Edit functionality coming soon!')));
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post'),
        content: Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              deleteMutation.mutate(widget.postId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Watch((context) {
        if (postDetail.isLoading) {
          return _buildLoadingState();
        }

        if (postDetail.isError) {
          return _buildErrorState();
        }

        final post = postDetail.data;
        if (post == null) {
          return _buildNotFoundState();
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserBanner(post),
              _buildPostContent(post),
              _buildCommentsSection(),
            ],
          ),
        );
      }),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Post Details'),
      backgroundColor: Colors.blue.shade50,
      foregroundColor: Colors.blue.shade800,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _handleEdit,
          icon: Icon(Icons.edit),
          tooltip: 'Edit Post',
        ),
        IconButton(
          onPressed: _handleDelete,
          icon: Icon(Icons.delete),
          color: Colors.red.shade600,
          tooltip: 'Delete Post',
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading post...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            SizedBox(height: 16),
            Text(
              'Failed to load post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              postDetail.error?.message ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => postDetail.refetch(),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              'Post not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The post you\'re looking for doesn\'t exist or has been removed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBanner(Post post) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue.shade200,
            child: Text(
              'U${post.userId}',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User ${post.userId}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Post #${post.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(Post post) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(post.title),
          SizedBox(height: 24),
          _buildBody(post.body),
          SizedBox(height: 24),
          if (post.tags.isNotEmpty) ...[
            _buildTags(post.tags),
            SizedBox(height: 24),
          ],
          _buildEngagementMetrics(post),
        ],
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
        height: 1.3,
      ),
    );
  }

  Widget _buildBody(String body) {
    return Text(
      body,
      style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey.shade700),
    );
  }

  Widget _buildTags(List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map(
                (tag) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEngagementMetrics(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engagement',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            _buildMetricCard(
              icon: Icons.thumb_up,
              value: post.reactions.likes,
              label: 'Likes',
              color: Colors.green,
            ),
            SizedBox(width: 12),
            _buildMetricCard(
              icon: Icons.thumb_down,
              value: post.reactions.dislikes,
              label: 'Dislikes',
              color: Colors.red,
            ),
            SizedBox(width: 12),
            _buildMetricCard(
              icon: Icons.visibility,
              value: post.views,
              label: 'Views',
              color: Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required int value,
    required String label,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color.shade600),
            SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.shade600,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: color.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment, color: Colors.blue.shade600),
              SizedBox(width: 8),
              Text(
                'Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Watch((context) {
            if (postComments.isLoading) {
              return _buildCommentsLoading();
            }

            if (postComments.isError) {
              return _buildCommentsError();
            }

            final comments = postComments.data ?? [];
            if (comments.isEmpty) {
              return _buildNoComments();
            }

            return _buildCommentsList(comments);
          }),
        ],
      ),
    );
  }

  Widget _buildCommentsLoading() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'Loading comments...',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsError() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          SizedBox(height: 8),
          Text(
            'Failed to load comments',
            style: TextStyle(color: Colors.red.shade700),
          ),
          SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => postComments.refetch(),
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoComments() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.comment_outlined, size: 48, color: Colors.grey.shade400),
          SizedBox(height: 12),
          Text(
            'No comments yet',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          SizedBox(height: 4),
          Text(
            'Be the first to comment on this post!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(List<Comment> comments) {
    return Column(
      children: comments
          .map((comment) => CommentCard(comment: comment))
          .toList(),
    );
  }
}
