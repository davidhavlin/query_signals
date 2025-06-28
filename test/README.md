# TestQuery Tests - Beginner's Guide

This guide explains how to understand and work with the test files for our custom query system.

## 🧪 What Are Tests?

Tests are **automatic checks** that make sure our code works correctly. Think of them like **quality control** - they catch bugs before users see them!

## 📁 Test Files

- `testquery_test.dart` - Contains all tests for our query system

## 🏃‍♂️ Running Tests

```bash
# Run all tests
flutter test

# Run just the query tests
flutter test test/testquery_test.dart

# Run a specific test
flutter test --plain-name "should create and execute a basic query"
```

## 📊 Test Results

When you run tests, you'll see:
- ✅ **Green/Passed**: Test worked correctly
- ❌ **Red/Failed**: Test found a problem  
- **Number summary**: `+16` means 16 tests passed

## 🔍 Understanding Test Structure

### Basic Test Format
```dart
test('description of what we're testing', () async {
  // ARRANGE: Set up test data
  final client = QueryClient();
  
  // ACT: Do the thing we want to test
  final query = client.useQuery(['test'], () async => 'data');
  
  // ASSERT: Check if it worked
  expect(query.data, equals('data'));
});
```

### Test Groups
Tests are organized in **groups** for easy navigation:

1. **Query Tests** - Basic query functionality
2. **Mutation Tests** - Data modification operations  
3. **QueryClient Tests** - Core client behavior
4. **QueryKey Tests** - Cache key management
5. **Error Handling Tests** - Error scenarios
6. **Performance Tests** - Speed and efficiency

## 🎯 Key Test Concepts

### 1. **expect()** - The Main Assertion
```dart
expect(actualValue, expectedValue, reason: 'Why this should be true');
```

### 2. **Matchers** - Different Ways to Check
```dart
expect(data, isNotNull);           // Should not be null
expect(list.length, 2);            // Should equal 2
expect(status, QueryStatus.success); // Should be specific value
expect(error, isA<Exception>());   // Should be certain type
```

### 3. **async/await** - Waiting for Operations
```dart
test('async test', () async {
  final result = await someAsyncFunction();
  expect(result, isNotNull);
});
```

## 🔧 Common Test Patterns

### Testing API Calls
```dart
// Mock function simulates real API
Future<String> mockApi() async {
  await Future.delayed(Duration(milliseconds: 50));
  return 'fake data';
}

// Test the mock
test('should call API', () async {
  final result = await mockApi();
  expect(result, 'fake data');
});
```

### Testing Error Handling
```dart
test('should handle errors', () async {
  final query = client.useQuery(['failing'], () async {
    throw Exception('Something broke');
  });
  
  await Future.delayed(Duration(milliseconds: 100));
  
  expect(query.isError, true);
  expect(query.error, isNotNull);
});
```

### Testing State Changes
```dart
test('should change status', () async {
  final query = client.useQuery(['test'], mockFetch);
  
  // Initially loading
  expect(query.isLoading, true);
  
  // Wait for completion
  await Future.delayed(Duration(milliseconds: 100));
  
  // Should be successful
  expect(query.isSuccess, true);
  expect(query.isLoading, false);
});
```

## 🎨 Test Organization

### setUp() and tearDown()
```dart
void main() {
  setUp(() {
    // Runs BEFORE each test - reset state
    QueryClient().removeQueries(null);
  });
  
  tearDown(() {
    // Runs AFTER each test - cleanup
  });
  
  test('my test', () {
    // Your test here
  });
}
```

## 🐛 Debugging Failed Tests

When a test fails:

1. **Read the error message** - It tells you what went wrong
2. **Check the line number** - Shows exactly where it failed  
3. **Look at the reason** - Custom message explaining the problem

Example failure:
```
Expected: not null
Actual: <null>
Should retrieve set data
test/testquery_test.dart:458:7
```

This means:
- **Line 458** expected something to not be null
- **But it was null** 
- **Reason**: "Should retrieve set data"

## ✅ Best Practices

1. **Write descriptive test names**
   ```dart
   // Good ✅
   test('should cache query results between calls')
   
   // Bad ❌  
   test('test query')
   ```

2. **Add helpful reason messages**
   ```dart
   expect(query.data, isNotNull, reason: 'Query should have data after fetch');
   ```

3. **Test both success and failure cases**
   ```dart
   test('should succeed with valid data');
   test('should fail with invalid data');
   ```

4. **Keep tests independent** - Each test should work alone

## 🎓 Learning More

- **Run tests frequently** while developing
- **Read test failures carefully** - they guide you to problems
- **Add new tests** when you add new features
- **Use tests as documentation** - they show how code should work

## 🚀 Next Steps

Try:
1. Run the existing tests to see them pass
2. Break something on purpose and see tests fail
3. Add a simple test for new functionality
4. Use tests to understand how the code works

**Remember**: Tests are your friends! They catch problems early and make you confident your code works correctly. 🎯 