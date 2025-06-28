abstract class HasId {
  String get id;
}

mixin Storable {
  String get id;
  Map<String, dynamic> toJson();
}
