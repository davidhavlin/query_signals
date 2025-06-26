// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:signals/signals_flutter.dart';
// import 'package:stage_ocean/common/services/dependency.service.dart';
// import 'package:stage_ocean/common/services/storage.service.dart';

// class StoredSignal<T> extends FlutterSignal<T> with StoredSignalMixin<T> {
//   @override
//   final String key;

//   @override
//   final KeyValueStore store;

//   @override
//   final bool clearCache;

//   StoredSignal(
//     super.internalValue, {
//     super.autoDispose,
//     super.debugLabel,
//     this.clearCache = false,
//     required this.key,
//   }) : store = getIt<StorageService>() {
//     init().ignore();
//   }
// }

// mixin StoredSignalMixin<T> on Signal<T> {
//   String get key;
//   KeyValueStore get store;
//   bool get clearCache;

//   bool isHydrated = false;
//   bool isSetInitialy = false;

//   final Completer<void> _hydrationCompleter = Completer<void>();

//   Future<void> waitForHydration() => _hydrationCompleter.future;

//   Future<void> init() async {
//     if (clearCache) await clear();
//     try {
//       final val = await load();
//       if (!isSetInitialy) {
//         super.value = val;
//       }
//     } catch (e) {
//       debugPrint('Error loading persisted signal: $e');
//     } finally {
//       isHydrated = true;
//       _hydrationCompleter.complete();
//     }
//   }

//   // @override
//   // T get value {
//   //   return super.value;
//   // }

//   @override
//   set value(T value) {
//     isSetInitialy = true;
//     super.value = value;
//     save(value).ignore();
//   }

//   Future<T> load() async {
//     final val = await store.getValue(key);
//     if (val == null) return value;
//     return decode(val);
//   }

//   Future<void> save(T value) async {
//     final str = encode(value);
//     await store.setValue(key, str);
//   }

//   Future<void> clear() async {
//     await store.clear(key);
//   }

//   T decode(String value) => jsonDecode(value);

//   String encode(T value) => jsonEncode(value);
// }

// class StoredEnumSignal<T extends Enum?> extends StoredSignal<T> {
//   final List<T> values;

//   StoredEnumSignal(super.val, String key, this.values, {super.clearCache})
//       : super(key: key);

//   @override
//   T decode(String value) => values.firstWhere((e) => e?.name == value);

//   @override
//   String encode(T value) => value!.name;
// }

// class StoredMapSignal<T> extends StoredSignal<T> {
//   final T Function(Map<String, dynamic> json) fromJson;

//   StoredMapSignal(super.val, String key, this.fromJson, {super.clearCache})
//       : super(key: key);

//   @override
//   T decode(String value) {
//     if (value.isEmpty) return null as T;
//     return fromJson(jsonDecode(value));
//   }

//   @override
//   String encode(T value) {
//     if (value == null) return '';
//     final dynamic json = (value as dynamic).toJson();
//     return jsonEncode(json);
//   }
// }

// class StoredSimpleListSignal<T> extends StoredSignal<List<T>> {
//   final T Function(Map<String, dynamic> json) fromJson;

//   StoredSimpleListSignal(String key, this.fromJson,
//       {List<T> initialValue = const [], bool clearCache = false})
//       : super(initialValue, key: key, clearCache: clearCache);

//   @override
//   set value(List<dynamic> value) {
//     isSetInitialy = true;
//     super.value = value.map((e) => fromJson(e)).toList();
//     save(super.value).ignore();
//   }

//   @override
//   List<T> decode(String value) {
//     if (value.isEmpty) return [];
//     final List<dynamic> jsonList = jsonDecode(value);
//     return jsonList.map((e) => fromJson(e as Map<String, dynamic>)).toList();
//   }

//   @override
//   String encode(List<T> value) {
//     final jsonList = value.map((e) => (e as dynamic).toJson()).toList();
//     return jsonEncode(jsonList);
//   }
// }
