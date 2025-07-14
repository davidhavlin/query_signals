import 'package:query_signals/p_signals/p_signal.dart';

/// A persisted enum signal with robust null handling and type safety
///
/// **Features:**
/// - Handles nullable enums properly
/// - Fallback to default value on decode errors
/// - Type-safe enum serialization/deserialization
///
/// **Usage:**
/// ```dart
/// enum Theme { light, dark, system }
///
/// final themeSignal = PEnumSignal<Theme>(
///   key: 'app_theme',
///   value: Theme.system,
///   values: Theme.values,
/// );
///
/// // For nullable enums
/// final optionalTheme = PEnumSignal<Theme?>(
///   key: 'optional_theme',
///   value: null,
///   values: [...Theme.values, null],
/// );
/// ```
class PEnumSignal<T extends Enum?> extends PSignal<T> {
  /// All possible values for this enum (including null if applicable)
  final List<T> values;

  PEnumSignal({
    required super.value,
    required super.key,
    required this.values,
    super.clearCache,
    super.fallbackValue,
    super.onError,
  }) : assert(
            values.contains(value), 'Initial value must be in the values list');

  @override
  T Function(String)? get customDecoder => (value) {
        // Handle null values
        if (value == 'null' || value.isEmpty) {
          final nullValue = values.firstWhere(
            (e) => e == null,
            orElse: () =>
                throw ArgumentError('Null value not allowed for this enum'),
          );
          return nullValue;
        }

        // Find enum by name
        final enumValue = values.firstWhere(
          (e) => e?.name == value,
          orElse: () => throw ArgumentError('Unknown enum value: $value'),
        );
        return enumValue;
      };

  @override
  String Function(T)? get customEncoder => (value) {
        if (value == null) return 'null';
        return value.name;
      };

  /// Get all possible enum values
  List<T> get allValues => List.unmodifiable(values);

  /// Check if the current value is null (for nullable enums)
  bool get isNull => value == null;

  /// Get the current value as non-null (throws if null)
  T get requireValue {
    final current = value;
    if (current == null) {
      throw StateError('Enum value is null');
    }
    return current;
  }

  /// Safely get the current value with a fallback
  T valueOr(T fallback) => value ?? fallback;
}
