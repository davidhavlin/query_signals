import 'package:example/app.dart';
import 'package:example/shared/service/storage.service.dart';
import 'package:example/shared/stores/app.store.dart';
import 'package:persist_signals/testquery/query_client.dart';
import 'package:flutter/material.dart';
import 'package:persist_signals/persist_signals.dart';

final q = QueryClient();

Future<void> main() async {
  // ensure initialized
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService().init();
  await PersistSignals.init(storage);
  await q.init();

  final appStore = AppStore();
  print('Hydration start');
  await appStore.waitForHydration();
  print('Hydration complete');
  runApp(const MyApp());
}
