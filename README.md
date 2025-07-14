# Persist Signals

A powerful persisted signals package for Flutter, built on top of signals_flutter with automatic persistence, error recovery, and optimistic updates.

## Features

- 🔄 **Automatic Persistence** - Values are automatically saved to storage on changes
- 🛡️ **Error Recovery** - Robust error handling with fallback values and recovery strategies
- ⚡ **Optimistic Updates** - Better UX with immediate UI updates and rollback on errors
- 📦 **Batch Operations** - Efficient batch updates for lists and maps
- 🔍 **Advanced Querying** - Built-in filtering, sorting, and search capabilities
- 🏗️ **Type Safety** - Full type safety with null handling
- 🚀 **Performance** - Optimized for large datasets with lazy loading
- 🔌 **Pluggable Storage** - Support for any storage backend

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  persist_signals: ^0.0.1
```

## Quick Start

### 1. Initialize the Client

```dart
import 'package:query_signals/persist_signals.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize with your storage implementation
  final storage = await StorageService().init();
  await PSignalsClient.init(storage);
  
  runApp(MyApp());
}
```

### 2. Create Signals

```dart
import 'package:query_signals/persist_signals.dart';

// Simple primitive signal
final counter = PSignal<int>(
  key: 'counter',
  value: 0,
);

// Complex object signal
final user = PSignal<User>(
  key: 'current_user',
  value: User.empty(),
  fromJson: User.fromJson,
  valueToJson: (user) => user.toJson(),
);

// Enum signal
final theme = PEnumSignal<ThemeMode>(
  key: 'theme_mode',
  value: ThemeMode.system,
  values: ThemeMode.values,
);
```

### 3. Use in Widgets

```dart
class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      return Column(
        children: [
          Text('Counter: ${counter.value}'),
          ElevatedButton(
            onPressed: () => counter.value++,
            child: Text('Increment'),
          ),
        ],
      );
    });
  }
}
```

## Signal Types

- `PSignal<T>` - Basic persistent signal for primitives and complex objects
- `PEnumSignal<T>` - Specialized signal for enum values
- `PMapSignal<K, V>` - Persistent map signal with individual key operations
- `PPrimitiveListSignal<T>` - Persistent list for primitive types
- `PComplexListSignal<T>` - Persistent list for complex objects with querying

## Query System

The package also includes a powerful query system for API calls:

```dart
final userQuery = Query<User>(
  key: 'user_${userId}',
  queryFn: () => apiService.getUser(userId),
);

// Use in widgets
Watch((context) {
  if (userQuery.isLoading) return CircularProgressIndicator();
  if (userQuery.hasError) return Text('Error: ${userQuery.error}');
  return Text('User: ${userQuery.data?.name}');
});
```

## Example

See the `/example` folder for a complete example app demonstrating all features.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
