# Flutter React Query 🚀

A React Query-like data fetching and caching system for Flutter using signals for ultimate reactivity.

## Features ✨

- **React Query patterns** - Familiar API if you know React Query
- **Flutter signals** - Use with `Watch()` for reactive UI
- **Automatic caching** - Persist data across app restarts
- **Stale-while-revalidate** - Show cached data instantly, refresh in background
- **Optimistic updates** - UI updates immediately, API calls happen async
- **Pure API functions** - Separate concerns: API calls vs data transformation
- **TypeScript-like types** - Full type safety with generics

## Quick Start 🏃‍♂️

### 1. Initialize QueryClient

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize your persist_signals storage
  PersistSignals.init(/* your storage */);
  
  // Initialize QueryClient
  await QueryClient().init();
  
  runApp(MyApp());
}
```

### 2. Create API Functions (Pure)

```dart
// Keep API functions pure - only HTTP calls, no transformation
Future<List<dynamic>> fetchPostsApi() => api.$get('/posts');
Future<Map<String, dynamic>> fetchPostApi(int id) => api.$get('/posts/$id');
```

### 3. Create Models

```dart
class Post {
  final int id;
  final String title;
  
  Post({required this.id, required this.title});
  
  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'],
    title: json['title'],
  );
}
```

### 4. Setup Queries with Transformers

```dart
class PostStore {
  final _client = QueryClient();
  
  // Query with automatic JSON -> Model transformation
  late final posts = _client.useQuery<List<Post>, List<dynamic>>(
    ['posts'], // Cache key
    fetchPostsApi, // Pure API function
    options: QueryOptions(
      staleDuration: Duration(minutes: 5), // When to background refresh
      // cacheDuration: Duration(hours: 1), // Optional: defaults to infinite
      transformer: (jsonList) => // Transform raw JSON to models
          jsonList.map((json) => Post.fromJson(json)).toList(),
    ),
  );
}
```

### 5. Use in Widgets with Watch

```dart
class PostsList extends StatelessWidget {
  final store = PostStore();
  
  Widget build(BuildContext context) {
    return Watch((context) {
      // Reactive to loading state
      if (store.posts.isLoading) {
        return CircularProgressIndicator();
      }
      
      // Reactive to error state
      if (store.posts.isError) {
        return Text('Error: ${store.posts.error}');
      }
      
      // Reactive to data changes
      final posts = store.posts.data ?? [];
      return ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) => 
            ListTile(title: Text(posts[index].title)),
      );
    });
  }
}
```

## Advanced Usage 🔥

### Mutations with Optimistic Updates

```dart
// Create mutation
late final updatePost = _client.useMutation<Post, Map<String, dynamic>>(
  (variables) async {
    final id = variables['id'] as int;
    final rawResult = await updatePostApi(id, variables);
    return Post.fromJson(rawResult);
  },
  options: MutationOptions(
    onSuccess: (updatedPost) {
      // Optimistic update: immediately update UI
      final currentPosts = posts.data ?? [];
      final updatedPosts = currentPosts.map((post) =>
        post.id == updatedPost.id ? updatedPost : post
      ).toList();
      _client.setQueryData(['posts'], updatedPosts);
    },
  ),
);

// Use in widget
ElevatedButton(
  onPressed: () => store.updatePost.mutate({
    'id': 1,
    'title': 'Updated Title',
  }),
  child: Text('Update Post'),
)
```

### Individual Item Queries

```dart
// Query for specific post
Query<Post, Map<String, dynamic>> getPost(int id) => 
    _client.useQuery<Post, Map<String, dynamic>>(
      ['posts', id], // Hierarchical cache key
      () => fetchPostApi(id),
      options: QueryOptions(
        transformer: (json) => Post.fromJson(json),
      ),
    );

// Use in detail page
Watch((context) {
  final postQuery = store.getPost(widget.postId);
  if (postQuery.isLoading) return CircularProgressIndicator();
  return Text(postQuery.data?.title ?? '');
})
```

### Cache Management

```dart
// Invalidate all post queries (refetch in background)
store.invalidatePosts();

// Prefetch data before needed
store.prefetchPost(123);

// Manual refetch (e.g., pull-to-refresh)
await store.posts.refetch();
```

### Hydration (Eliminate Loading Flicker)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage and QueryClient
  await QueryClient().init();
  
  // Create stores (this creates queries)
  final postStore = PostStore();
  
  // Wait for cached data to load BEFORE showing UI
  await postStore.waitForHydration();
  
  // Now app shows immediately with cached data!
  runApp(MyApp(postStore: postStore));
}

// Alternative: Wait for multiple stores
await Future.wait([
  postStore.waitForHydration(),
  userStore.waitForHydration(),
]);

// Alternative: Wait for all queries globally
await QueryClient().waitForHydration();
```

## Key Concepts 💡

### Caching Strategy

- **Stale Duration**: How long data is considered fresh (default: 5min)
- **Cache Duration**: How long data stays in memory/storage (default: 30min)
- **Background Refresh**: Shows cached data immediately, fetches fresh data behind scenes

### Status States

```dart
query.isLoading  // Initial load or manual refetch
query.isSuccess  // Data loaded successfully
query.isError    // Something went wrong
query.isStale    // Data exists but might be outdated
```

### React Query vs This Implementation

| React Query | Flutter Signals Query |
|-------------|----------------------|
| `useQuery()` | `_client.useQuery()` |
| `useMutation()` | `_client.useMutation()` |
| `queryClient.invalidateQueries()` | `_client.invalidateQueries()` |
| `isLoading`, `isError`, `data` | Same! |
| Observes with hooks | Observes with `Watch()` |

## Why This Approach? 🤔

### Pure API Functions
```dart
// ❌ Bad: Mixed concerns
final fetchPosts = () async {
  final response = await api.get('/posts');
  return response.map((json) => Post.fromJson(json)).toList();
};

// ✅ Good: Separated concerns
final fetchPostsApi = () => api.get('/posts'); // Pure API call

// Transform in query configuration
useQuery(['posts'], fetchPostsApi, 
  transformer: (jsonList) => jsonList.map((json) => Post.fromJson(json)).toList()
);
```

**Benefits:**
- API functions are testable in isolation
- Same API function can be used with different transformers
- Clear separation of HTTP logic vs business logic
- Easier to mock for testing

### Signals Integration
- Use `Watch()` for granular reactivity
- Signals automatically notify widgets of changes
- No need for `setState()` or manual rebuilds
- Compatible with your existing persist_signals architecture

## Disposal & Memory Management 🧹

### Manual Disposal (For Stores)
```dart
class PostStore {
  final posts = client.useQuery(...);
  final updatePost = client.useMutation(...);
  
  // Call this when store is no longer needed
  void dispose() {
    posts.dispose();
    updatePost.dispose();
  }
}

// In your app
final store = PostStore();
// Later...
store.dispose(); // Clean up signals
```

### Auto-Disposing Widgets
```dart
// Automatically disposes when widget is disposed
AutoDisposingQuery<List<Post>, List<dynamic>>(
  queryKey: ['posts'],
  queryFn: () => api.get('/posts'),
  transformer: (json) => json.map((e) => Post.fromJson(e)).toList(),
  builder: (context, query) {
    if (query.isLoading) return CircularProgressIndicator();
    return PostsList(posts: query.data ?? []);
  },
)

// Even simpler with Watch built-in
QueryWatch<List<Post>, List<dynamic>>(
  queryKey: ['posts'],
  queryFn: () => api.get('/posts'),
  transformer: (json) => json.map((e) => Post.fromJson(e)).toList(),
  builder: (context, query) => Text('Posts: ${query.data?.length ?? 0}'),
)
```

### Global Disposal
```dart
// When app shuts down
QueryClient().disposeAll();

// Dispose specific query
QueryClient().disposeQuery(['posts', 123]);
```

## Best Practices 📚

1. **Keep API functions pure** - Only HTTP calls, no transformations
2. **Use hierarchical cache keys** - `['posts']`, `['posts', id]`, `['users', id, 'posts']`
3. **Transform in queries** - Use the `transformer` option for JSON -> Model conversion
4. **Leverage optimistic updates** - Update UI immediately, let API confirm later
5. **Prefetch predictively** - Load data before user needs it
6. **Use proper stale durations** - Balance freshness vs performance
7. **Dispose queries properly** - Use stores for shared queries, auto-disposing widgets for one-offs
8. **Wait for hydration** - Eliminate loading flicker on app start

## Comparison with React Query

This implementation provides 95% of React Query's functionality:

✅ **Implemented:**
- Automatic caching with stale/fresh states
- Background refetching
- Optimistic updates
- Query invalidation
- Prefetching
- Loading/error states
- Persistent cache
- Infinite queries (pagination)
- Transformers for clean data transformation
- Auto-disposal with mixins
- Hydration to eliminate loading flicker

🚧 **Not implemented yet:**
- Dependent queries (queries that depend on other query results)
- Retry logic (automatic retry on failure)
- Network status detection (pause queries when offline)
- Request deduplication (prevent duplicate simultaneous requests)

Want these features? They can be added following the same patterns! 