import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import '../annotations/hydrated.dart';

class HydrateGenerator extends GeneratorForAnnotation<Hydrate> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Only classes can be annotated with @Hydrate',
        element: element,
      );
    }

    final libraryId = element.library.source.uri;
    final className = element.name;
    final signals = element.fields.where((field) {
      print('type: ${field.type}');
      print('element: ${field.type.element}');
      print('field: ${field}');

      final type = field.type.toString();
      return type.contains('CustomSignal');
    }).toList();

    final buffer = StringBuffer();
    // buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    // buffer.writeln();
    // buffer.writeln('part of \'${libraryId.pathSegments.last}\';');
    // buffer.writeln();
    buffer.writeln(
      '// **************************************************************************',
    );
    buffer.writeln('// HydrateGenerator');
    buffer.writeln(
      '// **************************************************************************',
    );
    buffer.writeln();
    buffer.writeln('extension \$${className}Hydration on $className {');
    buffer.writeln('  Future<void> waitForHydration() async {');
    buffer.writeln('    await Future.wait([');
    for (final signal in signals) {
      buffer.writeln('      ${signal.name}.waitForHydration(),');
    }
    buffer.writeln('    ]);');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }
}

// class HydratedGenerator extends GeneratorForAnnotation<Hydrated> {
//   @override
//   String generateForAnnotatedElement(
//     Element element, ConstantReader annotation, BuildStep buildStep) {

//     final className = (element as ClassElement).name;

//     final buffers = element.fields
//       .where((f) => f.type.toString() == 'CustomSignal')
//       .map((f) => '    await instance.${f.name}.waitForHydration();')
//       .join('\n');

//     return '''
// // GENERATED – DO NOT MODIFY
// extension ${className}Hydration on $className {
//   Future<void> waitForHydration() async {
// $buffers
//   }
// }
// ''';
//   }
// }
