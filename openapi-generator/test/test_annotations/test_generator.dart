import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:openapi_generator/src/utils.dart';
import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';
import 'package:source_gen/source_gen.dart' as src_gen;

class TestGenerator extends src_gen.GeneratorForAnnotation<Openapi> {
  final bool requireTestClassPrefix;

  const TestGenerator({this.requireTestClassPrefix = true});

  @override
  Iterable<String> generateForAnnotatedElement(Element element,
      src_gen.ConstantReader annotation, BuildStep buildStep) sync* {
    assert(!annotation.isNull, 'The source generator should\'nt be null');

    if (element is! ClassElement) {
      throw src_gen.InvalidGenerationSourceError(
        'Only supports annotated classes.',
        todo: 'Remove `TestAnnotation` from the associated element.',
        element: element,
      );
    }

    if (requireTestClassPrefix && !element.name.startsWith('TestClass')) {
      throw src_gen.InvalidGenerationSourceError(
        'All classes must start with `TestClass`.',
        todo: 'Rename the type or remove the `TestAnnotation` from class.',
        element: element,
      );
    }

    if (!(annotation.read('useNextGen').literalValue as bool)) {
      if (annotation.read('cachePath').literalValue != null) {
        throw src_gen.InvalidGenerationSourceError(
            'useNextGen must be set when using cachePath');
      }
    }

    // KEEP THIS IN LINE WITH THE FIELDS OF THE ANNOTATION CLASS
    final fields = [
      SupportedFields(name: 'additionalProperties', type: AdditionalProperties),
      SupportedFields(
          name: 'overwriteExistingFiles', isDeprecated: true, type: bool),
      SupportedFields(name: 'skipSpecValidation', type: bool),
      SupportedFields(name: 'inputSpecFile', isRequired: true, type: String),
      SupportedFields(name: 'templateDirectory', type: String),
      SupportedFields(name: 'generatorName', isRequired: true, type: Generator),
      SupportedFields(name: 'outputDirectory', type: Map),
      SupportedFields(name: 'typeMappings', type: Map),
      SupportedFields(name: 'importMappings', type: Map),
      SupportedFields(name: 'reservedWordsMappings', type: Map),
      SupportedFields(name: 'inlineSchemaNameMappings', type: Map),
      // SupportedFields(name:'inlineSchemaOptions'),
      SupportedFields(name: 'apiPackage', type: String),
      SupportedFields(name: 'fetchDependencies', type: bool),
      SupportedFields(name: 'runSourceGenOnOutput', type: bool),
      SupportedFields(name: 'alwaysRun', isDeprecated: true, type: bool),
      SupportedFields(name: 'cachePath', type: String),
      SupportedFields(name: 'useNextGen', type: bool),
      SupportedFields(name: 'projectPubspecPath', type: String),
    ]..sort((a, b) => a.name.compareTo(b.name));
    for (final field in fields) {
      final v = annotation.read(field.name);
      try {
        if ([
          'inputSpecFile',
          'projectPubspecPath',
          'apiPackage',
          'templateDirectory',
          'generatorName'
        ].any((element) => field.name == element)) {
          yield 'const ${field.name}=\'${convertToPropertyValue(v.objectValue)}\';\n';
        } else if (field.name == 'additionalProperties') {
          final mapping = v.revive().namedArguments.map(
              (key, value) => MapEntry(key, convertToPropertyValue(value)));
          // TODO: Is this the expected behaviour?
          // Iterable<MapEntry<String, dynamic>> entries;
          // if (v.objectValue.type is DioProperties) {
          //   entries = DioProperties.fromMap(mapping).toMap().entries;
          // } else if (v.objectValue.type is DioAltProperties) {
          //   entries = DioAltProperties.fromMap(mapping).toMap().entries;
          // } else {
          //   entries = AdditionalProperties.fromMap(mapping).toMap().entries;
          // }
          yield 'const ${field.name}=${mapping.entries.fold('', foldStringMap(valueModifier: (value) => '\'$value\''))};';
        } else {
          yield 'const ${field.name}=${convertToPropertyValue(v.objectValue)};\n';
        }
      } catch (_, __) {
        continue;
      }
    }
  }

  @override
  String toString() =>
      'TestGenerator (requireTestClassPrefix:$requireTestClassPrefix)';
}

class SupportedFields<T> {
  final String name;
  final bool isRequired;
  final bool isDeprecated;
  final T? type;

  const SupportedFields({
    required this.name,
    this.isDeprecated = false,
    this.isRequired = false,
    required this.type,
  });
}
