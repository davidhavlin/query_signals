import 'package:example/app.dart';
import 'package:example/stores/app.store.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  final appStore = AppStore();
  print('Hydration start');
  await appStore.waitForHydration();
  print('Hydration complete');
  runApp(const MyApp());
}
