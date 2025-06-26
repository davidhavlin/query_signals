import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'generator.dart';

Builder hydrateBuilder(BuilderOptions options) {
  return PartBuilder([HydrateGenerator()], '.g.dart');
}
