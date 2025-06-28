import 'package:example/posts/models/post.model.dart';
import 'package:example/shared/router/router.dart';
import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        router.pushPath(post.route);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Post #${post.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'User ${post.userId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post.body.length > 120
                    ? '${post.body.substring(0, 120)}...'
                    : post.body,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              if (post.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: post.tags
                      .take(3)
                      .map(
                        (tag) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 16, color: Colors.green.shade600),
                  SizedBox(width: 4),
                  Text(
                    '${post.reactions.likes}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.thumb_down, size: 16, color: Colors.red.shade600),
                  SizedBox(width: 4),
                  Text(
                    '${post.reactions.dislikes}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.visibility, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 4),
                  Text(
                    '${post.views}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
