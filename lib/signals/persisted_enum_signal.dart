import 'package:persist_signals/signals/persisted_signal.dart';

class PersistedEnumSignal<T extends Enum?> extends PersistedSignal<T> {
  final List<T> values;

  PersistedEnumSignal({
    required super.value,
    super.clearCache,
    required super.key,
    required this.values,
  });

  @override
  T Function(String)? get customDecoder =>
      (value) => values.firstWhere((e) => e?.name == value);

  @override
  String Function(T)? get customEncoder => (value) => value!.name;
}
