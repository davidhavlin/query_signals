// import 'dart:async';

// import 'package:signals/signals_flutter.dart';
// import 'package:sembast/sembast.dart';
// import 'package:stage_ocean/common/mixins/storable.mixin.dart';
// import 'package:stage_ocean/common/services/dependency.service.dart';
// import 'package:stage_ocean/common/services/storage.service.dart';

// class StoredListSignal<T extends Storable> extends ListSignal<T> {
//   final String key;
//   final T Function(Map<String, dynamic>) fromJson;
//   final StorageService storage;
//   final List<SortOrder>? sortOrders;
//   late StreamSubscription _subscription;

//   bool isHydrated = false;
//   bool isSetInitialy = false;
//   final Completer<void> _hydrationCompleter = Completer<void>();

//   StoredListSignal(
//     this.key,
//     this.fromJson, {
//     List<T> initialValue = const [],
//     this.sortOrders,
//   })  : storage = getIt<StorageService>(),
//         super(initialValue) {
//     _loadData();
//   }

//   Future<void> waitForHydration() => _hydrationCompleter.future;

//   Future<void> _loadData() async {
//     try {
//       final data = await storage.getRecords(key, sortOrders: sortOrders);
//       if (!isSetInitialy) {
//         value = data;
//       }
//     } finally {
//       if (!isHydrated) {
//         isHydrated = true;
//         _hydrationCompleter.complete();
//       }
//     }
//   }

//   @override
//   set value(List<dynamic>? newValue) {
//     isSetInitialy = true;
//     if (newValue == null) {
//       super.value = [];
//     } else {
//       super.value =
//           newValue.map((e) => fromJson(e as Map<String, dynamic>)).toList();
//     }
//     storage.setRecords(key, value);
//   }

//   @override
//   void add(T value) {
//     final existingIndex = indexWhere((item) => item.id == value.id);
//     if (existingIndex >= 0) {
//       super[existingIndex] = value;
//       storage.updateRecord(key, value.id, value.toJson());
//     } else {
//       super.add(value);
//       storage.addRecord(key, value);
//     }
//   }

//   @override
//   void addAll(Iterable<T> iterable) {
//     super.addAll(iterable);
//     storage.addRecords(key, iterable.toList());
//   }

//   @override
//   bool remove(Object? value) {
//     if (value is T) {
//       final removed = super.remove(value);
//       if (removed) {
//         storage.deleteRecord(key, value.id);
//       }
//       return removed;
//     }
//     return false;
//   }

//   @override
//   T removeAt(int index) {
//     final item = super.removeAt(index);
//     storage.deleteRecord(key, item.id);
//     return item;
//   }

//   @override
//   void removeWhere(bool Function(T element) test) {
//     final itemsToRemove = where(test).toList();
//     super.removeWhere(test);
//     storage.deleteRecords(key, itemsToRemove.map((e) => e.id).toList());
//   }

//   @override
//   void clear() {
//     super.clear();
//     storage.clearStore(key);
//   }

//   Future<T?> updateItem(String id, Map<String, dynamic> data) async {
//     final index = indexWhere((item) => item.id == id);
//     if (index >= 0) {
//       final currentItem = this[index];
//       final updatedJson = {...currentItem.toJson(), ...data};
//       final updatedItem = fromJson(updatedJson);

//       super[index] = updatedItem;
//       storage.updateRecord(key, id, data);
//       return updatedItem;
//     }

//     final newItem = fromJson(data);
//     add(newItem);
//     return newItem;
//   }

//   // Future<List<T>> filterItems(Filter filter) async {
//   //   final data = await storage.getRecords(key, filter: filter);
//   //   return data.map(fromJson).toList();
//   // }

//   @override
//   void dispose() {
//     _subscription.cancel();
//     super.dispose();
//   }
// }
