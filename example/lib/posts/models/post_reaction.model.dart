class PostReactions {
  final int likes;
  final int dislikes;

  PostReactions({required this.likes, required this.dislikes});

  factory PostReactions.fromJson(Map<String, dynamic> json) {
    return PostReactions(
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'likes': likes, 'dislikes': dislikes};
  }
}
