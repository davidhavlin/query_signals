/// Abstract class for models that can be serialized/deserialized for persistence
abstract class Storable {
  const Storable();

  /// Convert the model to a JSON map for storage
  Map<String, dynamic> toJson();

  /// Create an instance from a JSON map
  /// Note: This should be implemented as a static method in concrete classes
  /// Example: static User fromJson(Map<String, dynamic> json) => User(...);
}

abstract class StorableWithId extends Storable {
  String get id;

  const StorableWithId();
}
