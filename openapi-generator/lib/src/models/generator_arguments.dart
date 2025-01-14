import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:openapi_generator/src/extensions/type_methods.dart';
import 'package:openapi_generator/src/models/output_message.dart';
import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';
import 'package:source_gen/source_gen.dart' as src_gen;

import '../utils.dart';

/// The default storage location of the cached copy of the specification.
///
/// When the annotation has the [Openapi.cachePath] set this value isn't used.
final defaultCachedPath =
    '${Directory.current.path}${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}openapi-generator-cache.json';

/// Represents the Annotation fields passed to the [OpenapiGenerator].
class GeneratorArguments {
  /// Informs the generator to always run on changes.
  ///
  /// WARNING! This will soon be noop. See [useNextGen] for more
  /// details.
  ///
  /// Default: false
  @deprecated
  final bool alwaysRun;

  /// Informs the generator to follow the next generation path way.
  ///
  /// NextGen:
  ///   The next generation of the [OpenapiGenerator] will always run in the
  ///   event there is a change to the Openapi specification. In this version of
  ///   the generator the builder caches an instance of the current [inputFile],
  ///   if one doesn't already exist, this way in the event that are modifications
  ///   to the spec they can be generated. That cached copy is a translated
  ///   JSON copy (see [Yaml library]() about output).
  ///
  /// Default: false
  final bool useNextGen;

  /// The [cachePath] is the location of the translated copy of the [inputFile]
  /// before modifications.
  ///
  /// The default location is: .dart_tool/openapi-generator-cache.json
  final String cachePath;
  final bool isDebug;

  /// Use a custom pubspec file when generating.
  ///
  /// Defaults to the pubspec at the root of [Directory.current].
  final String? pubspecPath;

  /// The directory where the generated sources will be placed.
  ///
  /// Default: Directory.current.path
  final String outputDirectory;

  /// Informs the generator to run source gen on the output.
  ///
  /// Default: true
  final bool runSourceGen;

  /// Informs the generator to fetch dependencies within the new generated API.
  ///
  /// Default: true
  final bool shouldFetchDependencies;

  /// Informs the generator to skip validating the OpenApi specification.
  ///
  /// Default: false
  final bool skipValidation;

  /// Use the provided spec instead of one located in [Directory.current].
  ///
  /// Default: openapi.(ya?ml) | openapi.json
  String _inputFile;

  /// Provides an OAS spec file.
  ///
  /// When the [useNextGen] flag is set this should be the spec file configuration
  /// used instead.
  InputSpec inputSpec;

  /// The directory containing the template files.
  final String templateDirectory;

  /// Informs the generator what kind of library should be generated.
  ///
  /// Default: [Generator.dart]
  final Generator generator;

  /// Informs the generator to use the specified [wrapper] for Flutter commands.
  Wrapper get wrapper => additionalProperties?.wrapper ?? Wrapper.none;

  /// Defines mappings between a class and the import to be used.
  final Map<String, String> importMappings;

  /// Defines mappings between OpenAPI spec types and generated types.
  final Map<String, String> typeMappings;

  /// Adds reserved words mappings.
  ///
  /// Supported by [Generator.dio] & [Generator.dioAlt] generators.
  final Map<String, String> reservedWordsMappings;

  /// Additional properties to be passed into the OpenAPI compiler.
  final AdditionalProperties? additionalProperties;

  /// Defines a mapping for nested (inline) schema and the generated name.
  final Map<String, dynamic> inlineSchemaNameMappings;

  /// Customizes the way inline schema are handled.
  final InlineSchemaOptions? inlineSchemaOptions;

  GeneratorArguments({
    required src_gen.ConstantReader annotations,
    bool alwaysRun = false,
    String inputSpecFile = '',
    InputSpec inputSpec = const InputSpec.empty(),
    String templateDirectory = '',
    Generator generator = Generator.dart,
    Map<String, String> typeMapping = const {},
    Map<String, String> importMapping = const {},
    Map<String, String> reservedWordsMapping = const {},
    Map<String, String> inlineSchemaNameMapping = const {},
    AdditionalProperties? additionalProperties,
    InlineSchemaOptions? inlineSchemaOptions,
    bool skipValidation = false,
    bool runSourceGen = true,
    String? outputDirectory,
    bool fetchDependencies = true,
    bool useNextGen = false,
    String? cachePath,
    String? pubspecPath,
    bool isDebug = false,
  })  : alwaysRun = annotations.readPropertyOrDefault('alwaysRun', alwaysRun),
        _inputFile =
            annotations.readPropertyOrDefault('inputSpecFile', inputSpecFile),
        templateDirectory = annotations.readPropertyOrDefault(
            'templateDirectory', templateDirectory),
        generator =
            annotations.readPropertyOrDefault('generatorName', generator),
        typeMappings =
            annotations.readPropertyOrDefault('typeMappings', typeMapping),
        importMappings =
            annotations.readPropertyOrDefault('importMappings', importMapping),
        reservedWordsMappings = annotations.readPropertyOrDefault(
            'reservedWordsMappings', reservedWordsMapping),
        inlineSchemaNameMappings = annotations.readPropertyOrDefault(
            'inlineSchemaNameMappings', inlineSchemaNameMapping),
        additionalProperties = annotations.readPropertyOrDefault(
            'additionalProperties', additionalProperties),
        inlineSchemaOptions = annotations.readPropertyOrDefault(
            'inlineSchemaOptions', inlineSchemaOptions),
        skipValidation = annotations.readPropertyOrDefault(
            'skipSpecValidation', skipValidation),
        runSourceGen = annotations.readPropertyOrDefault(
            'runSourceGenOnOutput', runSourceGen),
        shouldFetchDependencies = annotations.readPropertyOrDefault(
            'fetchDependencies', fetchDependencies),
        outputDirectory = annotations.readPropertyOrDefault(
            'outputDirectory', outputDirectory ?? Directory.current.path),
        useNextGen =
            annotations.readPropertyOrDefault('useNextGen', useNextGen),
        cachePath = annotations.readPropertyOrDefault(
            'cachePath', cachePath ?? defaultCachedPath),
        pubspecPath = annotations.readPropertyOrDefault<String>(
            'projectPubspecPath',
            pubspecPath ??
                '${Directory.current.path}${Platform.pathSeparator}pubspec.yaml'),
        isDebug = annotations.readPropertyOrDefault('debugLogging', isDebug),
        inputSpec = annotations.readPropertyOrDefault('inputSpec', inputSpec);

  /// The stringified name of the [Generator].
  String get generatorName => generator == Generator.dart
      ? 'dart'
      : generator == Generator.dio
          ? 'dart-dio'
          : 'dart2-api';

  /// Informs the generator to generate source based on the [generator].
  ///
  /// This is only false in the case where [generator] is set to [Generator.dart]
  /// as that version of the [Generator] uses the 'dart:http' library as the
  /// networking layer.
  bool get shouldGenerateSources => generator != Generator.dart;

  /// Identifies if the specification is a remote specification.
  ///
  /// Used when the specification is hosted on an external server. This will cause
  /// the compiler to pulls from the remote source. When this is true a cache will
  /// still be created but a warning will be emitted to the user.
  bool get isRemote => useNextGen
      ? inputSpec is RemoteSpec
      : _inputFile.isNotEmpty
          ? RegExp(r'^https?://').hasMatch(_inputFile)
          : false;

  bool get hasLocalCache => File(cachePath).existsSync();

  /// Looks for a default spec file within [Directory.current] if [_inputFile]
  /// wasn't set.
  ///
  /// Looks for
  /// In the event that a specification file isn't provided look within the
  /// project to see if one of the supported defaults, a file named
  /// openapi.(ya?ml|json), is present.
  ///
  /// Subsequent calls will be able to use the [_inputFile] when successful in
  /// the event that a default is found.
  Future<String> get inputFileOrFetch async {
    if (useNextGen) {
      if (isRemote) {
        return (inputSpec as RemoteSpec).url.toString();
      }
      if (!File(inputSpec.path).existsSync()) {
        return Future.error(
          OutputMessage(
            message:
                'No spec file found. One must be present in the project or hosted remotely.',
            level: Level.SEVERE,
            stackTrace: StackTrace.current,
          ),
        );
      }
      return inputSpec.path;
    }

    final curr = Directory.current;
    if (_inputFile.isNotEmpty) {
      return _inputFile;
    }

    try {
      final entry = curr.listSync().firstWhere(
          (e) => RegExp(r'^.*/(openapi\.(ya?ml|json))$').hasMatch(e.path));
      _inputFile = entry.path;
      return _inputFile;
    } catch (e, st) {
      return Future.error(
        OutputMessage(
          message:
              'No spec file found. One must be present in the project or hosted remotely.',
          level: Level.SEVERE,
          additionalContext: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// The arguments to be passed to generator jar file.
  FutureOr<List<String>> get jarArgs async => [
        'generate',
        if (outputDirectory.isNotEmpty) '-o=$outputDirectory',
        '-i=${await inputFileOrFetch}',
        if (templateDirectory.isNotEmpty) '-t=$templateDirectory',
        '-g=$generatorName',
        if (skipValidation) '--skip-validate-spec',
        if (reservedWordsMappings.isNotEmpty)
          '--reserved-words-mappings=${reservedWordsMappings.entries.fold('', foldStringMap())}',
        if (inlineSchemaNameMappings.isNotEmpty)
          '--inline-schema-name-mappings=${inlineSchemaNameMappings.entries.fold('', foldStringMap())}',
        if (importMappings.isNotEmpty)
          '--import-mappings=${importMappings.entries.fold('', foldStringMap())}',
        if (typeMappings.isNotEmpty)
          '--type-mappings=${typeMappings.entries.fold('', foldStringMap())}',
        if (inlineSchemaOptions != null)
          '--inline-schema-options=${inlineSchemaOptions!.toMap().entries.fold('', foldStringMap(keyModifier: convertToPropertyKey))}',
        if (additionalProperties != null)
          '--additional-properties=${convertAdditionalProperties(additionalProperties!).fold('', foldStringMap(keyModifier: convertToPropertyKey))}'
      ];

  Iterable<MapEntry<String, dynamic>> convertAdditionalProperties(
      AdditionalProperties props) {
    if (props is DioProperties) {
      return props.toMap().entries;
    } else if (props is DioAltProperties) {
      return props.toMap().entries;
    } else {
      return props.toMap().entries;
    }
  }
}
