# PSignals - Advanced Persistent Signals for Flutter

A powerful, type-safe, and feature-rich library for persistent state management in Flutter applications using signals. Built on top of the `signals` package with automatic persistence, error recovery, and optimistic updates.

## Features

- 🔄 **Automatic Persistence** - Values are automatically saved to storage on changes
- 🛡️ **Error Recovery** - Robust error handling with fallback values and recovery strategies
- ⚡ **Optimistic Updates** - Better UX with immediate UI updates and rollback on errors
- 📦 **Batch Operations** - Efficient batch updates for lists and maps
- 🔍 **Advanced Querying** - Built-in filtering, sorting, and search capabilities
- 🏗️ **Type Safety** - Full TypeScript-style type safety with null handling
- 🚀 **Performance** - Optimized for large datasets with lazy loading and individual record operations
- 🔌 **Pluggable Storage** - Support for any storage backend (SharedPreferences, SQLite, etc.)

## Quick Start

### 1. Initialize the Client

```dart
import 'package:persist_signals/p_signals/client/p_signals_client.dart';

void main() {
  // Initialize with your storage implementation
  PSignalsClient.init(YourStorageImplementation());
  
  runApp(MyApp());
}
```

### 2. Create Signals

```dart
import 'package:persist_signals/p_signals/p_signal.dart';

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
  onError: (error, stackTrace) {
    print('User signal error: $error');
  },
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

### PSignal<T> - Basic Persistent Signal

For simple values and complex objects with custom serialization.

```dart
// Primitive types
final isLoggedIn = PSignal<bool>(
  key: 'is_logged_in',
  value: false,
);

// Complex objects
final settings = PSignal<AppSettings>(
  key: 'app_settings',
  value: AppSettings.defaults(),
  fromJson: AppSettings.fromJson,
  valueToJson: (settings) => settings.toJson(),
  fallbackValue: AppSettings.defaults(),
);
```

### PEnumSignal<T> - Enum Signal

Type-safe enum persistence with null handling.

```dart
enum Theme { light, dark, system }

final themeSignal = PEnumSignal<Theme>(
  key: 'app_theme',
  value: Theme.system,
  values: Theme.values,
);

// Nullable enum
final optionalTheme = PEnumSignal<Theme?>(
  key: 'optional_theme',
  value: null,
  values: [...Theme.values, null],
);
```

### PListSignal<T> - Simple List Signal

For lists that are saved as a single blob. Best for small to medium lists.

```dart
final tags = PListSignal<String>(
  key: 'tags',
  value: ['flutter', 'dart'],
);

// Complex objects
final todos = PListSignal<Todo>(
  key: 'todos',
  value: [],
  fromJson: Todo.fromJson,
  valueToJson: (todo) => todo.toJson(),
);
```

### PComplexListSignal<T> - Advanced List Signal

For large lists with individual item operations, optimistic updates, and advanced querying.

```dart
final posts = PComplexListSignal<Post>(
  key: 'posts',
  fromJson: Post.fromJson,
  optimisticUpdates: true,
  onError: (error, stackTrace) {
    // Handle errors
  },
);

// Usage
posts.add(newPost);
posts.addAll([post1, post2]);
await posts.updateItem(postId, {'title': 'New Title'});
await posts.batchUpdate([
  {'id': 'post1', 'title': 'Title 1'},
  {'id': 'post2', 'title': 'Title 2'},
]);

// Advanced querying
final publishedPosts = posts.filter((post) => post.isPublished);
final authorPosts = posts.findByField('authorId', 'user123');
posts.sortByField('createdAt', ascending: false);
```

### PMapSignal<K, V> - Map Signal

For key-value storage with automatic persistence.

```dart
final userPreferences = PMapSignal<String, dynamic>(
  key: 'user_preferences',
  value: {},
);

// Usage
userPreferences['theme'] = 'dark';
userPreferences['notifications'] = true;
```

## Advanced Features

### Error Handling

```dart
final signal = PSignal<String>(
  key: 'data',
  value: 'default',
  fallbackValue: 'fallback',
  onError: (error, stackTrace) {
    // Custom error handling
    logger.error('Signal error', error, stackTrace);
    analytics.recordError(error);
  },
);

// Check for errors
if (signal.lastError != null) {
  // Handle error state
}
```

### Hydration Management

```dart
// Wait for hydration
await signal.waitForHydration();

// Check hydration state
if (signal.isHydrated) {
  // Signal is ready
}

// Manual refresh
await signal.refresh();
```

### Optimistic Updates

```dart
final posts = PComplexListSignal<Post>(
  key: 'posts',
  fromJson: Post.fromJson,
  optimisticUpdates: true, // Default: true
);

// Updates are immediately reflected in UI
// If storage fails, changes are automatically rolled back
await posts.updateItem(postId, {'title': 'New Title'});
```

### Batch Operations

```dart
// Batch update multiple items
await posts.batchUpdate([
  {'id': 'post1', 'title': 'Title 1', 'content': 'Content 1'},
  {'id': 'post2', 'title': 'Title 2', 'content': 'Content 2'},
]);

// Batch add
posts.addAll([post1, post2, post3]);
```

### Advanced Querying

```dart
// Filter by predicate
final publishedPosts = posts.filter((post) => post.isPublished);

// Find by field value
final authorPosts = posts.findByField('authorId', 'user123');

// Sort by field
posts.sortByField('createdAt', ascending: false);

// Get unique values
final uniqueTags = posts.getUniqueValues('tags');

// Get statistics
final stats = posts.stats;
print('Total posts: ${stats['count']}');
```

## Best Practices

### 1. Use Appropriate Signal Types

- **PSignal**: Simple values and small objects
- **PListSignal**: Small to medium lists (< 100 items)
- **PComplexListSignal**: Large lists with frequent individual operations
- **PMapSignal**: Key-value storage
- **PEnumSignal**: Enum values

### 2. Handle Errors Gracefully

```dart
final signal = PSignal<Data>(
  key: 'critical_data',
  value: Data.empty(),
  fallbackValue: Data.safe(),
  onError: (error, stackTrace) {
    // Log error
    logger.error('Critical data error', error, stackTrace);
    
    // Show user-friendly message
    showErrorSnackbar('Failed to save data');
  },
);
```

### 3. Use Hydration for Critical Data

```dart
class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        userSignal.waitForHydration(),
        settingsSignal.waitForHydration(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LoadingScreen();
        }
        return MainApp();
      },
    );
  }
}
```

### 4. Optimize List Operations

```dart
// For large lists, use PComplexListSignal
final posts = PComplexListSignal<Post>(
  key: 'posts',
  fromJson: Post.fromJson,
  optimisticUpdates: true,
);

// Use batch operations for multiple updates
await posts.batchUpdate(updates);

// Use specific operations instead of replacing entire list
posts.add(newPost);          // ✅ Good
posts.value = [...posts, newPost]; // ❌ Less efficient
```

### 5. Type Safety with Nullable Values

```dart
// Nullable enum
final optionalValue = PEnumSignal<Status?>(
  key: 'status',
  value: null,
  values: [...Status.values, null],
);

// Safe access
if (!optionalValue.isNull) {
  final status = optionalValue.requireValue;
}

// With fallback
final status = optionalValue.valueOr(Status.unknown);
```

## Storage Implementation

Implement the `BasePersistedStorage` interface for your storage backend:

```dart
class MyStorage extends BasePersistedStorage {
  @override
  Future<void> init() async {
    // Initialize your storage
  }

  @override
  Future<String?> get(String key) async {
    // Get value by key
  }

  @override
  Future<void> set(String key, String value) async {
    // Set value by key
  }

  // ... implement other methods
}
```

## Performance Tips

1. **Use appropriate signal types** for your data size
2. **Enable optimistic updates** for better UX
3. **Batch operations** when possible
4. **Wait for hydration** for critical data
5. **Use fallback values** for error recovery
6. **Implement proper error handling**

## Testing

```dart
void main() {
  group('PSignal Tests', () {
    setUp(() {
      PSignalsClient.init(MockStorage());
    });

    tearDown(() {
      PSignalsClient.reset();
    });

    test('should persist values', () async {
      final signal = PSignal<String>(
        key: 'test',
        value: 'initial',
      );

      await signal.waitForHydration();
      signal.value = 'updated';

      // Verify storage was updated
      final stored = await signal.store.get('test');
      expect(stored, '"updated"');
    });
  });
}
```

## Migration Guide

### From v1.x to v2.x

- `PersistedPrimitiveListSignal` → `PListSignal`
- Added required `key` parameter to constructors
- Added error handling callbacks
- Enhanced type safety

## License

MIT License - see LICENSE file for details. 