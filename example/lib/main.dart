import 'package:example/app.dart';
import 'package:example/shared/service/storage.service.dart';
import 'package:example/shared/stores/app.store.dart';
import 'package:flutter/material.dart';
import 'package:query_signals/query_signals/client/query_client.dart';

final q = QueryClient();

Future<void> main() async {
  // ensure initialized
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService().init();
  await q.init(storage: storage);

  final appStore = AppStore();
  print('Hydration start');
  await appStore.waitForHydration();
  print('Hydration complete');
  runApp(const MyApp());
}
