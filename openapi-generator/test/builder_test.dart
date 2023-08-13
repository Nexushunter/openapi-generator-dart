import 'dart:convert';
import 'dart:io';

import 'package:build_test/build_test.dart';
import 'package:openapi_generator/src/gen_on_spec_changes.dart';
import 'package:openapi_generator/src/models/generator_arguments.dart';
import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'utils.dart';

/// We test the build runner by mocking the specs and then checking the output
/// content for the expected generate command.
void main() {
  group('generator dio', () {
    test('to generate appropriate openapi cli command', () async {
      expect(
          await generate('''
      @Openapi(
          additionalProperties:
              DioProperties(pubName: 'petstore_api', pubAuthor: 'Johnny dep...'),
          inputSpecFile: '../openapi-spec.yaml',
          typeMappings: {'Pet': 'ExamplePet'},
          generatorName: Generator.dio,
          runSourceGenOnOutput: true,
          alwaysRun: true,
          outputDirectory: 'api/petstore_api')
      '''),
          contains(
              'generate -o api/petstore_api -i ../openapi-spec.yaml -g dart-dio --type-mappings=Pet=ExamplePet --additional-properties=allowUnicodeIdentifiers=false,ensureUniqueParams=true,useEnumExtension=true,prependFormOrBodyParameters=false,pubAuthor=Johnny dep...,pubName=petstore_api,legacyDiscriminatorBehavior=true,sortModelPropertiesByRequiredFlag=true,sortParamsByRequiredFlag=true,wrapper=none,dateLibrary=core,serializationLibrary=built_value'));
    });

    test('to generate command with import and type mappings', () async {
      expect(
          await generate('''
      @Openapi(
          inputSpecFile: '../openapi-spec.yaml',
          typeMappings: {'int-or-string':'IntOrString'},
          importMappings: {'IntOrString':'./int_or_string.dart'},
          generatorName: Generator.dio)
      '''),
          contains(
              'generate -o ${Directory.current.path} -i ../openapi-spec.yaml -g dart-dio --import-mappings=IntOrString=./int_or_string.dart --type-mappings=int-or-string=IntOrString'));
    });

    test('to generate command with inline schema mappings', () async {
      expect(
          await generate('''
      @Openapi(
          inputSpecFile: '../openapi-spec.yaml',
          typeMappings: {'int-or-string':'IntOrString'},
          inlineSchemaNameMappings: {'inline_object_2':'SomethingMapped','inline_object_4':'nothing_new'},
          generatorName: Generator.dio)
      '''),
          contains('''
              generate -o ${Directory.current.path} -i ../openapi-spec.yaml -g dart-dio --inline-schema-name-mappings=inline_object_2=SomethingMapped,inline_object_4=nothing_new --type-mappings=int-or-string=IntOrString
              '''
              .trim()));
    });

    // test('to generate command with inline schema options', () async {
    //   expect(await generate('''
    //   @Openapi(
    //       inputSpecFile: '../openapi-spec.yaml',
    //       inlineSchemaOptions: InlineSchemaOptions(skipSchemaReuse: true,refactorAllofInlineSchemas: true,resolveInlineEnums: true),
    //       generatorName: Generator.dio)
    //   '''), contains('''
    //           generate -i ../openapi-spec.yaml -g dart-dio --type-mappings=int-or-string=IntOrString --inline-schema-name-mappings=inline_object_2=SomethingMapped,inline_object_4=nothing_new
    //           '''.trim()));
    // });
  });

  group('generator dioAlt', () {
    test('to generate appropriate openapi cli command', () async {
      expect(
          await generate('''
      @Openapi(
          additionalProperties:
              DioProperties(pubName: 'petstore_api', pubAuthor: 'Johnny dep...'),
          inputSpecFile: '../openapi-spec.yaml',
          typeMappings: {'Pet': 'ExamplePet'},
          generatorName: Generator.dio,
          runSourceGenOnOutput: true,
          alwaysRun: true,
          outputDirectory: 'api/petstore_api')
      '''),
          contains('''
              generate -o api/petstore_api -i ../openapi-spec.yaml -g dart-dio --type-mappings=Pet=ExamplePet --additional-properties=allowUnicodeIdentifiers=false,ensureUniqueParams=true,useEnumExtension=true,prependFormOrBodyParameters=false,pubAuthor=Johnny dep...,pubName=petstore_api,legacyDiscriminatorBehavior=true,sortModelPropertiesByRequiredFlag=true,sortParamsByRequiredFlag=true,wrapper=none,dateLibrary=core,serializationLibrary=built_value
          '''
              .trim()));
    });

    test('to generate command with import and type mappings for dioAlt',
        () async {
      expect(
          await generate('''
        @Openapi(
            inputSpecFile: '../openapi-spec.yaml',
            typeMappings: {'int-or-string':'IntOrString'},
            importMappings: {'IntOrString':'./int_or_string.dart'},
            generatorName: Generator.dioAlt)
      '''),
          contains(
              'generate -o ${Directory.current.path} -i ../openapi-spec.yaml -g dart2-api --import-mappings=IntOrString=./int_or_string.dart --type-mappings=int-or-string=IntOrString'));
    });
  });

  group('NextGen', () {
    late String generatedOutput;
    final specPath =
        'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml';
    final f = File('${testSpecPath}managed-cache.json');
    setUpAll(() async {
      generatedOutput = await generate('''
        @Openapi(
            inputSpecFile: '$specPath',
            typeMappings: {'int-or-string':'IntOrString'},
            importMappings: {'IntOrString':'./int_or_string.dart'},
            generatorName: Generator.dioAlt,
            useNextGen: true,
            )
      ''');
    });
    test('Logs warning when using remote spec', () async {
      expect(
          generatedOutput,
          contains(
              ':: Using a remote specification, a cache will still be create but may be outdated. ::'));
    });
    group('runs', () {
      setUpAll(() {
        f.writeAsStringSync('{}');
      });
      tearDown(() {
        if (f.existsSync()) {
          f.deleteSync();
        }
      });
      test('when the spec is dirty', () async {
        final src = '''
        @Openapi(
            inputSpecFile: '$specPath',
            useNextGen: true,
            cachePath: '${f.path}'
            )
      ''';
        generatedOutput = await generate(src);
        expect(
            generatedOutput, contains('Dirty Spec found. Running generation.'));
      });
      test('and terminates early when there is no diff', () async {
        f.writeAsStringSync(jsonEncode(await loadSpec(specPath: specPath)));
        final src = '''
        @Openapi(
            inputSpecFile: '$specPath',
            useNextGen: true,
            cachePath: '${f.path}'
            )
      ''';
        generatedOutput = await generate(src);
        expect(generatedOutput,
            contains(':: No diff between versions, not running generator. ::'));
      });
      test('openApiJar with expected args', () async {
        f.writeAsStringSync(jsonEncode({'someKey': 'someValue'}));
        final annotations = (await resolveSource(
                File('$testSpecPath/next_gen_builder_test_config.dart')
                    .readAsStringSync(),
                (resolver) async =>
                    (await resolver.findLibraryByName('test_lib'))!))
            .getClass('TestClassConfig')!
            .metadata
            .map((e) => ConstantReader(e.computeConstantValue()!))
            .first;
        final args = GeneratorArguments(annotations: annotations);
        generatedOutput = await generate('''
        @Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
)
        ''');
        expect(
            generatedOutput,
            contains(
                'OpenapiGenerator :: [${(await args.jarArgs).join(' ')}]'));
      });
      group('source gen', () {
        group('uses Flutter', () {
          group('with wrapper', () {
            test('fvm', () async {
              generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  additionalProperties: AdditionalProperties(
    wrapper: Wrapper.fvm,
  ),
)
          ''');
              expect(
                  generatedOutput, contains('Running source code generation.'));
              expect(
                  generatedOutput,
                  contains(
                      'fvm pub run build_runner build --delete-conflicting-outputs'));
            });
            test('flutterw', () async {
              generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  additionalProperties: AdditionalProperties(
    wrapper: Wrapper.flutterw,
  ),
)
          ''');
              expect(
                  generatedOutput, contains('Running source code generation.'));
              expect(
                  generatedOutput,
                  contains(
                      './flutterw pub run build_runner build --delete-conflicting-outputs'));
            });
          });
          test('without wrapper', () async {
            final annotations = (await resolveSource(
                    File('$testSpecPath/next_gen_builder_flutter_test_config.dart')
                        .readAsStringSync(),
                    (resolver) async =>
                        (await resolver.findLibraryByName('test_lib'))!))
                .getClass('TestClassConfig')!
                .metadata
                .map((e) => ConstantReader(e.computeConstantValue()!))
                .first;
            final args = GeneratorArguments(annotations: annotations);
            generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  projectPubspecPath: './test/specs/flutter_pubspec.test.yaml',
)
          ''');

            expect(args.wrapper, Wrapper.none);
            expect(
                generatedOutput, contains('Running source code generation.'));
            expect(
                generatedOutput,
                contains(
                    'flutter pub run build_runner build --delete-conflicting-outputs'));
          });
        });
        test('uses dart', () async {
          final annotations = (await resolveSource(
                  File('$testSpecPath/next_gen_builder_test_config.dart')
                      .readAsStringSync(),
                  (resolver) async =>
                      (await resolver.findLibraryByName('test_lib'))!))
              .getClass('TestClassConfig')!
              .metadata
              .map((e) => ConstantReader(e.computeConstantValue()!))
              .first;
          final args = GeneratorArguments(annotations: annotations);
          generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  projectPubspecPath: './test/specs/dart_pubspec.test.yaml',
)
          ''');

          expect(args.wrapper, Wrapper.none);
          expect(generatedOutput, contains('Running source code generation.'));
          expect(
              generatedOutput,
              contains(
                  'dart pub run build_runner build --delete-conflicting-outputs'));
        });
        group('except when', () {
          test('flag is set', () async {
            final annotations = (await resolveSource(
                    '''
library test_lib;

import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';

@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  runSourceGenOnOutput: false,
)
class TestClassConfig extends OpenapiGeneratorConfig {}
                    ''',
                    (resolver) async =>
                        (await resolver.findLibraryByName('test_lib'))!))
                .getClass('TestClassConfig')!
                .metadata
                .map((e) => ConstantReader(e.computeConstantValue()!))
                .first;
            final args = GeneratorArguments(annotations: annotations);

            expect(args.runSourceGen, isFalse);
            generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  runSourceGenOnOutput: false,
)
            ''');
            expect(generatedOutput,
                contains('Skipping source gen step due to flag being set.'));
          });
          test('generator is dart', () async {
            final annotations = (await resolveSource(
                    '''
library test_lib;

import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';

@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dart,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
)
class TestClassConfig extends OpenapiGeneratorConfig {}
                    ''',
                    (resolver) async =>
                        (await resolver.findLibraryByName('test_lib'))!))
                .getClass('TestClassConfig')!
                .metadata
                .map((e) => ConstantReader(e.computeConstantValue()!))
                .first;
            final args = GeneratorArguments(annotations: annotations);
            expect(args.runSourceGen, isTrue);
            generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dart,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
)
            ''');
            expect(
                generatedOutput,
                contains(
                    'Skipping source gen because generator does not need it.'));
          });
        });
        test('logs when successful', () async {
          generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  projectPubspecPath: './test/specs/dart_pubspec.test.yaml',
)
          ''');
          expect(generatedOutput, contains('Codegen completed successfully.'));
          expect(generatedOutput, contains('Sources generated successfully.'));
        });
      });
      group('fetch dependencies', () {
        test('except when flag is present', () async {
          generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  projectPubspecPath: './test/specs/dart_pubspec.test.yaml',
  fetchDependencies: false,
)
          ''');
          expect(generatedOutput,
              contains('Skipping install step because flag was set.'));
        });
        test('succeeds', () async {
          generatedOutput = await generate('''
@Openapi(
  inputSpecFile:
      'https://raw.githubusercontent.com/Nexushunter/tagmine-api/main/openapi.yaml',
  generatorName: Generator.dio,
  useNextGen: true,
  cachePath: './test/specs/managed-cache.json',
  projectPubspecPath: './test/specs/dart_pubspec.test.yaml',
)
          ''');
          expect(generatedOutput,
              contains('Installing dependencies with generated source.'));
          expect(generatedOutput, contains('Install completed successfully.'));
        });
      });
      group('update cache', () {
        final src = '''
        @Openapi(
            inputSpecFile: '$specPath',
            useNextGen: true,
            cachePath: '${f.path}'
            )
      ''';

        test('creating a cache file when not found', () async {
          // Ensure that other tests don't make this available;
          if (f.existsSync()) {
            f.deleteSync();
          }
          generatedOutput = await generate(src);
          expect(
              generatedOutput, contains('No local cache found. Creating one.'));
          expect(f.existsSync(), isTrue);
          expect(jsonDecode(f.readAsStringSync()),
              await loadSpec(specPath: specPath));
        });
        test('updates the cache file when found', () async {
          f.writeAsStringSync(jsonEncode({'someKey': 'someValue'}));
          generatedOutput = await generate(src);
          final expectedSpec = await loadSpec(specPath: specPath);
          final actualSpec = jsonDecode(f.readAsStringSync());
          expect(actualSpec, expectedSpec);
          expect(generatedOutput,
              contains('Local cache found. Overwriting existing one.'));
        });
        test('logs when successful', () async {
          f.writeAsStringSync(jsonEncode({'someKey': 'someValue'}));
          generatedOutput = await generate(src);
          expect(
              generatedOutput, contains('Successfully cached spec changes.'));
        });
      });
    });
  });
}