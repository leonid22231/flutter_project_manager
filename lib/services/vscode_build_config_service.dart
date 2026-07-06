import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/flutter_platform_utils.dart';
import 'package:project_manager/models/build_config_source.dart';
import 'package:project_manager/models/build_run_mode.dart';
import 'package:project_manager/models/project_build_config.dart';

class VscodeBuildConfigService {
  Future<ProjectBuildScanResult> scanProject(
    String projectRoot, {
    List<String> platforms = const [],
  }) async {
    final configs = <ProjectBuildConfig>[];
    String? errorMessage;

    final tasksFile = File(p.join(projectRoot, '.vscode', 'tasks.json'));
    final tasksJsonExists = tasksFile.existsSync();
    final resolvedPlatforms = resolveProjectPlatforms(
      projectRoot: projectRoot,
      projectPlatforms: platforms,
    );

    if (tasksJsonExists) {
      try {
        configs.addAll(
          parseTasksJson(
            await tasksFile.readAsString(),
            tasksFile.path,
          ),
        );
      } catch (error) {
        errorMessage = 'tasks.json: $error';
      }
    } else {
      configs.addAll(defaultFlutterConfigs(platforms: resolvedPlatforms));
    }

    return ProjectBuildScanResult(
      configs: configs,
      tasksJsonExists: tasksJsonExists,
      usingDefaultConfigs: !tasksJsonExists,
      tasksJsonPath: tasksJsonExists ? tasksFile.path : null,
      resolvedPlatforms: resolvedPlatforms,
      errorMessage: errorMessage,
    );
  }

  List<ProjectBuildConfig> parseTasksJson(String content, String sourceFile) {
    final decoded = decodeJsonc(content);
    if (decoded is! Map) return const [];

    final tasks = decoded['tasks'];
    if (tasks is! List) return const [];

    final configs = <ProjectBuildConfig>[];
    for (var index = 0; index < tasks.length; index++) {
      final item = tasks[index];
      if (item is! Map) continue;
      final config = _taskFromMap(
        map: Map<String, dynamic>.from(item),
        sourceFile: sourceFile,
        index: index,
      );
      if (config != null) configs.add(config);
    }
    return configs;
  }

  List<ProjectBuildConfig> defaultFlutterConfigs({
    List<String> platforms = const [],
  }) {
    final normalized = normalizeFlutterPlatformNames(platforms);
    final configs = <ProjectBuildConfig>[];

    void addPlatformBuilds(String platform, List<ProjectBuildConfig> items) {
      if (normalized.contains(platform)) {
        configs.addAll(items);
      }
    }

    addPlatformBuilds('Android', [
      _defaultConfig(
        id: 'flutter-build-apk',
        name: 'Flutter: Build APK',
        mode: BuildRunMode.build,
        commandArgs: const ['build', 'apk'],
      ),
      _defaultConfig(
        id: 'flutter-build-appbundle',
        name: 'Flutter: Build App Bundle',
        mode: BuildRunMode.build,
        commandArgs: const ['build', 'appbundle'],
      ),
    ]);
    addPlatformBuilds('iOS', [
      _defaultConfig(
        id: 'flutter-build-ios',
        name: 'Flutter: Build iOS',
        mode: BuildRunMode.build,
        commandArgs: const ['build', 'ios'],
      ),
    ]);
    addPlatformBuilds('Web', [
      _defaultConfig(
        id: 'flutter-build-web',
        name: 'Flutter: Build Web',
        mode: BuildRunMode.build,
        commandArgs: const ['build', 'web'],
      ),
    ]);
    addPlatformBuilds('Windows', [
      _defaultConfig(
        id: 'flutter-build-windows',
        name: 'Flutter: Build Windows',
        mode: BuildRunMode.build,
        commandArgs: const ['build', 'windows'],
      ),
    ]);
    addPlatformBuilds('macOS', [
      _defaultConfig(
        id: 'flutter-build-macos',
        name: 'Flutter: Build macOS',
        mode: BuildRunMode.build,
        commandArgs: const ['build', 'macos'],
      ),
    ]);
    addPlatformBuilds('Linux', [
      _defaultConfig(
        id: 'flutter-build-linux',
        name: 'Flutter: Build Linux',
        mode: BuildRunMode.build,
        commandArgs: const ['build', 'linux'],
      ),
    ]);

    return configs;
  }

  ProjectBuildConfig? _taskFromMap({
    required Map<String, dynamic> map,
    required String sourceFile,
    required int index,
  }) {
    final label = map['label']?.toString().trim();
    if (label == null || label.isEmpty) return null;

    final type = map['type']?.toString() ?? 'shell';
    final group = _taskGroupName(map['group']);
    final isBackground = map['isBackground'] == true;
    final cwd = map['options'] is Map
        ? map['options']['cwd']?.toString()
        : null;

    if (type == 'flutter' || type == 'dart') {
      final command = map['command']?.toString() ?? 'run';
      final args = _stringList(map['args']);
      final mode = _modeFromTask(label: label, group: group, command: command);
      final commandArgs = <String>[command, ...args];

      return ProjectBuildConfig(
        id: 'task:$sourceFile:$index:$label',
        name: label,
        source: BuildConfigSource.tasksJson,
        mode: mode,
        type: type,
        cwd: cwd,
        executable: 'flutter',
        commandArgs: commandArgs,
        sourceFile: sourceFile,
        taskGroup: group,
        isBackground: isBackground,
      );
    }

    final shellStructured = parseStructuredShellTask(map);
    if (shellStructured != null) {
      return ProjectBuildConfig(
        id: 'task:$sourceFile:$index:$label',
        name: label,
        source: BuildConfigSource.tasksJson,
        mode: _modeFromTask(
          label: label,
          group: group,
          command: shellStructured.displayCommand,
        ),
        type: type,
        cwd: cwd,
        executable: shellStructured.executable,
        commandArgs: shellStructured.args,
        sourceFile: sourceFile,
        taskGroup: group,
        isBackground: isBackground,
      );
    }

    final shellCommand = buildShellCommandLine(map);
    if (shellCommand == null) return null;

    return ProjectBuildConfig(
      id: 'task:$sourceFile:$index:$label',
      name: label,
      source: BuildConfigSource.tasksJson,
      mode: _modeFromTask(label: label, group: group, command: shellCommand),
      type: type,
      cwd: cwd,
      shellCommand: shellCommand,
      sourceFile: sourceFile,
      taskGroup: group,
      isBackground: isBackground,
    );
  }

  ProjectBuildConfig _defaultConfig({
    required String id,
    required String name,
    required BuildRunMode mode,
    required List<String> commandArgs,
  }) {
    return ProjectBuildConfig(
      id: id,
      name: name,
      source: BuildConfigSource.flutterDefault,
      mode: mode,
      executable: 'flutter',
      commandArgs: commandArgs,
    );
  }

  BuildRunMode _modeFromTask({
    required String label,
    required String? group,
    required String command,
  }) {
    final lower = '$label $command'.toLowerCase();
    if (group == 'test' || lower.contains(' test')) return BuildRunMode.test;
    if (lower.contains('profile')) return BuildRunMode.profile;
    if (lower.contains('release')) return BuildRunMode.release;
    if (lower.contains('attach')) return BuildRunMode.attach;
    if (group == 'build' || lower.contains('build')) return BuildRunMode.build;
    if (lower.contains('debug')) return BuildRunMode.debug;
    return BuildRunMode.custom;
  }

  String? _taskGroupName(dynamic group) {
    if (group is String) return group;
    if (group is Map) return group['kind']?.toString();
    return null;
  }
}

class StructuredShellTask {
  const StructuredShellTask({
    required this.executable,
    required this.args,
  });

  final String executable;
  final List<String> args;

  String get displayCommand {
    if (args.isEmpty) return executable;
    return '$executable ${args.join(' ')}';
  }
}

StructuredShellTask? parseStructuredShellTask(Map<String, dynamic> map) {
  final command = map['command'];
  final args = _stringList(map['args']);

  if (command is Map) {
    final commandMap = Map<String, dynamic>.from(command);
    final executable = commandMap['program']?.toString() ??
        commandMap['command']?.toString();
    final commandArgs = _stringList(commandMap['args']);
    if (executable == null || executable.trim().isEmpty) return null;
    return StructuredShellTask(
      executable: executable.trim(),
      args: commandArgs,
    );
  }

  if (command is! String) return null;
  final trimmed = command.trim();
  if (trimmed.isEmpty) return null;

  if (!trimmed.contains(RegExp(r'\s')) && args.isNotEmpty) {
    return StructuredShellTask(executable: trimmed, args: args);
  }

  if (args.isEmpty && !trimmed.contains(RegExp(r'\s'))) {
    return StructuredShellTask(executable: trimmed, args: const []);
  }

  return null;
}

String? buildShellCommandLine(Map<String, dynamic> map) {
  final command = map['command'];
  final args = _stringList(map['args']);

  if (command is Map) {
    final structured = parseStructuredShellTask(map);
    if (structured == null) return null;
    return quoteShellArguments([
      structured.executable,
      ...structured.args,
    ]);
  }

  if (command is String && command.trim().isNotEmpty) {
    final trimmed = command.trim();
    if (args.isEmpty) return trimmed;
    return quoteShellArguments([trimmed, ...args]);
  }

  return null;
}

String quoteShellArguments(List<String> parts) {
  return parts.map(quoteShellArgument).join(' ');
}

String quoteShellArgument(String value) {
  if (value.isEmpty) return '""';

  final needsQuoting = value.contains(RegExp(r'\s')) ||
      value.contains('"') ||
      value.contains('&') ||
      value.contains('|') ||
      value.contains('<') ||
      value.contains('>') ||
      value.contains('^') ||
      value.contains('%');

  if (!needsQuoting) return value;
  return '"${value.replaceAll('"', r'\"')}"';
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null) item.toString(),
  ];
}

dynamic decodeJsonc(String content) {
  final normalized = normalizeJsonc(content);
  return jsonDecode(normalized);
}

String normalizeJsonc(String content) {
  var normalized = content;
  if (normalized.startsWith('\uFEFF')) {
    normalized = normalized.substring(1);
  }
  normalized = stripJsonComments(normalized);
  normalized = stripTrailingCommas(normalized);
  return normalized;
}

String stripTrailingCommas(String content) {
  final buffer = StringBuffer();
  var index = 0;
  var inString = false;
  var escaped = false;

  while (index < content.length) {
    final char = content[index];

    if (inString) {
      buffer.write(char);
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      index++;
      continue;
    }

    if (char == '"') {
      inString = true;
      buffer.write(char);
      index++;
      continue;
    }

    if (char == ',') {
      var lookAhead = index + 1;
      while (lookAhead < content.length && _isJsonWhitespace(content[lookAhead])) {
        lookAhead++;
      }
      if (lookAhead < content.length &&
          (content[lookAhead] == ']' || content[lookAhead] == '}')) {
        index++;
        continue;
      }
    }

    buffer.write(char);
    index++;
  }

  return buffer.toString();
}

bool _isJsonWhitespace(String char) {
  return char == ' ' || char == '\t' || char == '\r' || char == '\n';
}

String stripJsonComments(String content) {
  final buffer = StringBuffer();
  var index = 0;
  var inString = false;
  var escaped = false;
  var inLineComment = false;
  var inBlockComment = false;

  while (index < content.length) {
    final char = content[index];
    final next = index + 1 < content.length ? content[index + 1] : '';

    if (inLineComment) {
      if (char == '\n') {
        inLineComment = false;
        buffer.write(char);
      }
      index++;
      continue;
    }

    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        index += 2;
      } else {
        index++;
      }
      continue;
    }

    if (inString) {
      buffer.write(char);
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      index++;
      continue;
    }

    if (char == '"') {
      inString = true;
      buffer.write(char);
      index++;
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      index += 2;
      continue;
    }

    if (char == '/' && next == '*') {
      inBlockComment = true;
      index += 2;
      continue;
    }

    buffer.write(char);
    index++;
  }

  return buffer.toString();
}
