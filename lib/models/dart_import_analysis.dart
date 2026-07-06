enum DartImportKind {
  dartSdk,
  package,
  projectFile,
  relative,
  part,
  partOf,
}

class DartImportEntry {
  const DartImportEntry({
    required this.uri,
    required this.kind,
    required this.directive,
    this.packageName,
    this.resolvedAbsolutePath,
    this.resolvedRelativePath,
    this.targetExists = false,
  });

  final String uri;
  final DartImportKind kind;
  final String directive;
  final String? packageName;
  final String? resolvedAbsolutePath;
  final String? resolvedRelativePath;
  final bool targetExists;

  bool get isExternalPackage =>
      kind == DartImportKind.package && resolvedAbsolutePath == null;
}

class DartImportAnalysis {
  const DartImportAnalysis({
    required this.imports,
    this.projectPackageName,
  });

  final List<DartImportEntry> imports;
  final String? projectPackageName;

  List<DartImportEntry> get projectFiles => imports
      .where(
        (entry) =>
            entry.kind == DartImportKind.projectFile ||
            entry.kind == DartImportKind.relative ||
            entry.kind == DartImportKind.part ||
            entry.kind == DartImportKind.partOf,
      )
      .toList();

  List<DartImportEntry> get externalPackages =>
      imports.where((entry) => entry.isExternalPackage).toList();

  List<DartImportEntry> get dartSdkImports =>
      imports.where((entry) => entry.kind == DartImportKind.dartSdk).toList();

  String toMarkdown() {
    final buffer = StringBuffer('# Dependencies\n\n');
    buffer.writeln(
      'Imports detected in this Dart file.'
      '${projectPackageName != null ? ' Project package: `$projectPackageName`.' : ''}',
    );
    buffer.writeln();

    _writeSection(
      buffer,
      title: 'Project files',
      entries: _uniqueEntries(projectFiles),
      nameBuilder: (entry) =>
          entry.resolvedRelativePath ?? entry.uri,
    );

    _writeSection(
      buffer,
      title: 'Packages',
      entries: _uniqueEntries(externalPackages),
      nameBuilder: (entry) => entry.packageName ?? entry.uri,
    );

    _writeSection(
      buffer,
      title: 'Dart SDK',
      entries: _uniqueEntries(dartSdkImports),
      nameBuilder: (entry) => entry.uri,
    );

    return buffer.toString().trimRight();
  }

  void _writeSection(
    StringBuffer buffer, {
    required String title,
    required List<DartImportEntry> entries,
    required String Function(DartImportEntry entry) nameBuilder,
  }) {
    if (entries.isEmpty) return;

    buffer.writeln('## $title');
    buffer.writeln();

    buffer.writeln('| Name | Import | Status |');
    buffer.writeln('|------|--------|--------|');

    for (final entry in entries) {
      final name = nameBuilder(entry);
      final status = entry.targetExists
          ? 'linked'
          : entry.kind == DartImportKind.relative ||
                  entry.kind == DartImportKind.part ||
                  entry.kind == DartImportKind.partOf
              ? 'not found'
              : 'external';
      buffer.writeln(
        '| `$name` | `${entry.directive}` | $status |',
      );
    }

    buffer.writeln();
  }

  List<DartImportEntry> _uniqueEntries(List<DartImportEntry> entries) {
    final seen = <String>{};
    final unique = <DartImportEntry>[];

    for (final entry in entries) {
      final key = '${entry.resolvedRelativePath ?? entry.uri}|${entry.directive}';
      if (seen.add(key)) {
        unique.add(entry);
      }
    }

    return unique;
  }
}
