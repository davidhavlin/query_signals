import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'p_signal_test.dart' as p_signal_tests;
import 'p_enum_signal_test.dart' as p_enum_signal_tests;
import 'p_list_signal_test.dart' as p_list_signal_tests;
import 'p_map_signal_test.dart' as p_map_signal_tests;
import 'p_complex_list_signal_test.dart' as p_complex_list_signal_tests;

void main() {
  group('🚀 PSignals Library - Complete Test Suite', () {
    print('\n' + '=' * 60);
    print('🧪 Running Complete PSignals Test Suite');
    print('=' * 60);

    group('📦 PSignal (Basic Signal)', () {
      p_signal_tests.main();
    });

    group('🎯 PEnumSignal (Enum Signal)', () {
      p_enum_signal_tests.main();
    });

    group('📝 PListSignal (List Signal)', () {
      p_list_signal_tests.main();
    });

    group('🗂️ PMapSignal (Map Signal)', () {
      p_map_signal_tests.main();
    });

    group('📋 PComplexListSignal (Advanced List Signal)', () {
      p_complex_list_signal_tests.main();
    });

    setUpAll(() {
      print('\n✅ Test suite setup complete!');
      print('📊 Testing all signal types with comprehensive coverage:');
      print('   • Basic persistence and hydration');
      print('   • Error handling and recovery');
      print('   • Complex data structures');
      print('   • Individual record operations');
      print('   • Optimistic updates & rollback');
      print('   • Batch operations');
      print('   • Edge cases and performance');
      print('   • Custom serialization');
      print('   • Concurrent modifications');
    });

    tearDownAll(() {
      print('\n' + '=' * 60);
      print('🎉 PSignals Test Suite Complete!');
      print('📈 Coverage includes:');
      print('   ✓ Basic Signal Operations');
      print('   ✓ Enum Value Management');
      print('   ✓ List Manipulation');
      print('   ✓ Map Operations');
      print('   ✓ Complex List Operations');
      print('   ✓ Optimistic Updates');
      print('   ✓ Individual Record Operations');
      print('   ✓ Batch Operations');
      print('   ✓ Error Handling & Recovery');
      print('   ✓ Persistence Layer');
      print('   ✓ Edge Cases');
      print('=' * 60 + '\n');
    });
  });
}
