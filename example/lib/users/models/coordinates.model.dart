class Coordinates {
  final double lat;
  final double lng;

  Coordinates({required this.lat, required this.lng});

  factory Coordinates.fromJson(Map<String, dynamic> json) =>
      Coordinates(lat: json['lat'] as double, lng: json['lng'] as double);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}
