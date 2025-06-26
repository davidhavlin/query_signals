import 'dart:async';

import 'package:example/enums/some.enum.dart';
import 'package:example/models/company.model.dart';
import 'package:example/models/user.model.dart';
import 'package:example/testgeneration/annotations/hydrated.dart';
import 'package:persist_signals/signals/persisted_enum_signal.dart';
import 'package:persist_signals/signals/persisted_map_signal.dart';
import 'package:persist_signals/signals/persisted_signal.dart';
import 'package:signals/signals_flutter.dart';
import 'package:persist_signals/persist_signals.dart';

part 'app.store.g.dart';

final testMap = Company(
  name: 'Companty name',
  catchPhrase: 'Some catch phrase',
  bs: 'Some bs',
);

@Hydrate()
class AppStore {
  final someString = '';
  final someInt = 0;
  final someBool = false;

  final someSimpleList = <String>[];
  final someMap = <String, dynamic>{};
  final someSet = <String>{};
  final SomeEnum someEnum = SomeEnum.one;

  final users = <User>[];
  final User? selectedUser = null;

  final test1 = CustomSignal('test1');
  final test2 = CustomSignal('test2');

  final test3 = PersistedSignal(key: 'test3', value: '');
  final test4 = PersistedSignal(key: 'test4', value: 0);
  final test41 = PersistedSignal<int?>(key: 'test4', value: null);
  final test5 = PersistedSignal(key: 'test5', value: false);
  final test81 = PersistedSignal(
    key: 'test81',
    fromJson: Company.fromJson,
    value: Company(
      name: 'Companty name',
      catchPhrase: 'Some catch phrase',
      bs: 'Some bs',
    ),
  );
  final test82 = PersistedSignal(
    key: 'test82',
    fromJson: Company.fromJson,
    value: null,
  );

  final test9 = PersistedEnumSignal(
    key: 'test9',
    value: SomeEnum.one,
    values: SomeEnum.values,
  );
  final test10 = PersistedEnumSignal(
    key: 'test9',
    value: null,
    values: SomeEnum.values,
  );
  final test8 = PersistedMapSignal(
    key: 'test8',
    value: {'field1': 'value1', 'field2': 'value2'},
  );

  // final test6 = PersistedSignal<List<String>>([]);
  // final test7 = PersistedSignal<Map<String, dynamic>>({});
  // final test10 = PersistedSignal<User?>(null);

  final someComplexList = <Map<String, dynamic>>[];
}

class CustomSignal {
  final Completer<void> _hydrationCompleter = Completer<void>();
  String value;

  Future<void> waitForHydration() => _hydrationCompleter.future;

  Future<void> init(String innerValue) async {
    value = 'loading...';
    await Future.delayed(const Duration(seconds: 1));
    value = innerValue;
    _hydrationCompleter.complete();
  }

  CustomSignal(this.value) {
    init(value);
  }
}
