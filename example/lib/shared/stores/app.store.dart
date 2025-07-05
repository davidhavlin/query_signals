import 'dart:async';

import 'package:example/shared/enums/some.enum.dart';
import 'package:persist_signals/p_signals/p_enum_signal.dart';
import 'package:persist_signals/p_signals/p_map_signal.dart';
import 'package:persist_signals/p_signals/p_signal.dart';
import 'package:persist_signals/testgeneration/annotations/hydrated.dart';

part 'app.store.g.dart';

@Hydrate()
class AppStore {
  final someString = '';
  final someInt = 0;
  final someBool = false;

  final someSimpleList = <String>[];
  final someMap = <String, dynamic>{};
  final someSet = <String>{};
  final SomeEnum someEnum = SomeEnum.one;

  // final users = <User>[];
  // final User? selectedUser = null;

  final test1 = CustomSignal('test1');
  final test2 = CustomSignal('test2');

  final test3 = PSignal(key: 'test3', value: '');
  final test4 = PSignal(key: 'test4', value: 0);
  final test41 = PSignal<int?>(key: 'test4', value: null);
  final test5 = PSignal(key: 'test5', value: false);
  // final test81 = PSignal(
  //   key: 'test81',
  //   fromJson: Company.fromJson,
  //   value: Company(
  //     name: 'Companty name',
  //     catchPhrase: 'Some catch phrase',
  //     bs: 'Some bs',
  //   ),
  // );
  // final test82 = PSignal(
  //   key: 'test82',
  //   fromJson: Company.fromJson,
  //   value: null,
  // );

  final test9 = PEnumSignal(
    key: 'test9',
    value: SomeEnum.one,
    values: SomeEnum.values,
  );
  final test10 = PEnumSignal(
    key: 'test9',
    value: null,
    values: SomeEnum.values,
  );
  final test8 = PMapSignal(
    key: 'test8',
    value: {'field1': 'value1', 'field2': 'value2'},
  );

  // final test6 = PSignal<List<String>>([]);
  // final test7 = PSignal<Map<String, dynamic>>({});
  // final test10 = PSignal<User?>(null);

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
