import 'package:persist_signals/p_signals/p_signal.dart';

class PEnumSignal<T extends Enum?> extends PSignal<T> {
  final List<T> values;

  PEnumSignal({
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
