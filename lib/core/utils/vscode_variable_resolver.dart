import 'dart:io';

import 'package:path/path.dart' as p;

class VscodeVariableResolver {
  VscodeVariableResolver({
    required this.workspaceFolder,
  });

  final String workspaceFolder;

  String get workspaceFolderBasename => p.basename(workspaceFolder);

  String resolve(String value) {
    var resolved = value;
    resolved = resolved.replaceAll(r'${workspaceFolder}', workspaceFolder);
    resolved = resolved.replaceAll(r'${workspaceRoot}', workspaceFolder);
    resolved = resolved.replaceAll(
      r'${workspaceFolderBasename}',
      workspaceFolderBasename,
    );
    resolved = resolved.replaceAllMapped(
      RegExp(r'\$\{env:([^}]+)\}'),
      (match) => Platform.environment[match.group(1)!] ?? '',
    );
    return resolved;
  }

  String? resolveNullable(String? value) {
    if (value == null) return null;
    final resolved = resolve(value);
    return resolved.isEmpty ? null : resolved;
  }

  List<String> resolveList(List<String> values) {
    return values.map(resolve).toList();
  }
}
