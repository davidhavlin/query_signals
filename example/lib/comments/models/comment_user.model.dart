class CommentUser {
  final int id;
  final String username;
  final String fullName;

  CommentUser({
    required this.id,
    required this.username,
    required this.fullName,
  });

  factory CommentUser.fromJson(Map<String, dynamic> json) => CommentUser(
    id: json['id'] as int,
    username: json['username'] as String,
    fullName: json['fullName'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
  };
}
