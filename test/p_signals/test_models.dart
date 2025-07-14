import 'package:query_signals/p_signals/models/storable.model.dart';

/// Test user model for complex object testing
class TestUser extends StorableWithId {
  @override
  final String id;
  final String name;
  final String email;
  final int age;
  final bool isActive;

  const TestUser({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.isActive,
  }) : super();

  factory TestUser.fromJson(Map<String, dynamic> json) {
    return TestUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      age: json['age'] as int,
      isActive: json['isActive'] as bool,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'age': age,
      'isActive': isActive,
    };
  }

  TestUser copyWith({
    String? id,
    String? name,
    String? email,
    int? age,
    bool? isActive,
  }) {
    return TestUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestUser &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.age == age &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        age.hashCode ^
        isActive.hashCode;
  }

  @override
  String toString() {
    return 'TestUser(id: $id, name: $name, email: $email, age: $age, isActive: $isActive)';
  }

  static TestUser get sample => const TestUser(
        id: 'user1',
        name: 'John Doe',
        email: 'john@example.com',
        age: 30,
        isActive: true,
      );

  static TestUser get sampleInactive => const TestUser(
        id: 'user2',
        name: 'Jane Smith',
        email: 'jane@example.com',
        age: 25,
        isActive: false,
      );
}

/// Test settings model for complex object testing
class TestSettings extends Storable {
  final String theme;
  final bool notificationsEnabled;
  final double fontSize;
  final List<String> favoriteColors;

  const TestSettings({
    required this.theme,
    required this.notificationsEnabled,
    required this.fontSize,
    required this.favoriteColors,
  }) : super();

  factory TestSettings.fromJson(Map<String, dynamic> json) {
    return TestSettings(
      theme: json['theme'] as String,
      notificationsEnabled: json['notificationsEnabled'] as bool,
      fontSize: (json['fontSize'] as num).toDouble(),
      favoriteColors: List<String>.from(json['favoriteColors'] as List),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'notificationsEnabled': notificationsEnabled,
      'fontSize': fontSize,
      'favoriteColors': favoriteColors,
    };
  }

  TestSettings copyWith({
    String? theme,
    bool? notificationsEnabled,
    double? fontSize,
    List<String>? favoriteColors,
  }) {
    return TestSettings(
      theme: theme ?? this.theme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fontSize: fontSize ?? this.fontSize,
      favoriteColors: favoriteColors ?? this.favoriteColors,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestSettings &&
        other.theme == theme &&
        other.notificationsEnabled == notificationsEnabled &&
        other.fontSize == fontSize &&
        _listEquals(other.favoriteColors, favoriteColors);
  }

  @override
  int get hashCode {
    return theme.hashCode ^
        notificationsEnabled.hashCode ^
        fontSize.hashCode ^
        favoriteColors.hashCode;
  }

  @override
  String toString() {
    return 'TestSettings(theme: $theme, notificationsEnabled: $notificationsEnabled, fontSize: $fontSize, favoriteColors: $favoriteColors)';
  }

  static TestSettings get defaults => const TestSettings(
        theme: 'dark',
        notificationsEnabled: true,
        fontSize: 14.0,
        favoriteColors: ['blue', 'green'],
      );
}

/// Test enum for enum signal testing
enum TestTheme { light, dark, system, custom }

/// Test todo model for complex list testing
class TestTodo extends StorableWithId {
  @override
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final int priority;

  const TestTodo({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.createdAt,
    required this.priority,
  });

  factory TestTodo.fromJson(Map<String, dynamic> json) {
    return TestTodo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      isCompleted: json['isCompleted'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      priority: json['priority'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'priority': priority,
    };
  }

  TestTodo copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    int? priority,
  }) {
    return TestTodo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestTodo &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.isCompleted == isCompleted &&
        other.createdAt == createdAt &&
        other.priority == priority;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        isCompleted.hashCode ^
        createdAt.hashCode ^
        priority.hashCode;
  }

  @override
  String toString() {
    return 'TestTodo(id: $id, title: $title, description: $description, isCompleted: $isCompleted, createdAt: $createdAt, priority: $priority)';
  }

  static TestTodo createSample(String id, {String? title, int priority = 1}) {
    return TestTodo(
      id: id,
      title: title ?? 'Todo $id',
      description: 'Description for todo $id',
      isCompleted: false,
      createdAt: DateTime.now(),
      priority: priority,
    );
  }
}

/// Helper function to compare lists
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  if (identical(a, b)) return true;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
