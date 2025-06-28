import 'package:example/comments/models/comment_user.model.dart';

class Comment {
  final int id;
  final String body;
  final int postId;
  final int likes;
  final CommentUser user;

  Comment({
    required this.id,
    required this.body,
    required this.postId,
    required this.likes,
    required this.user,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as int,
    body: json['body'] as String,
    postId: json['postId'] as int,
    likes: json['likes'] as int,
    user: CommentUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'postId': postId,
    'likes': likes,
    'user': user.toJson(),
  };
}
