import 'package:example/posts/models/post_reaction.model.dart';
import 'package:persist_signals/p_signals/models/storable.model.dart';

class Post extends StorableWithId {
  @override
  final String id;
  final int userId;
  final String title;
  final String body;
  final List<String> tags;
  final PostReactions reactions;
  final int views;

  Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.reactions,
    required this.views,
  });

  String get route => '/post-detail/$id';

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      userId: json['userId'] ?? 0,
      id: json['id'].toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      reactions: PostReactions.fromJson(json['reactions'] ?? {}),
      views: json['views'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'id': id,
      'title': title,
      'body': body,
      'tags': tags,
      'reactions': reactions.toJson(),
      'views': views,
    };
  }
}
