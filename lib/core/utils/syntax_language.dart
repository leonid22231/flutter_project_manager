/// Maps file extensions to highlight.js language identifiers.
String? syntaxLanguageForFile(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return null;
  }

  final ext = fileName.substring(dotIndex + 1).toLowerCase();

  return switch (ext) {
    'dart' => 'dart',
    'yaml' || 'yml' => 'yaml',
    'json' => 'json',
    'html' || 'htm' => 'xml',
    'xml' => 'xml',
    'css' => 'css',
    'scss' => 'scss',
    'js' || 'mjs' => 'javascript',
    'ts' => 'typescript',
    'kt' || 'kts' => 'kotlin',
    'java' => 'java',
    'swift' => 'swift',
    'gradle' => 'gradle',
    'groovy' => 'groovy',
    'sh' || 'bash' || 'zsh' => 'bash',
    'cmake' => 'cmake',
    'md' => 'markdown',
    'sql' => 'sql',
    'proto' => 'protobuf',
    'plist' => 'xml',
    'properties' => 'properties',
    'toml' => 'ini',
    'ini' => 'ini',
    'c' || 'h' => 'c',
    'cpp' || 'cc' || 'hpp' => 'cpp',
    'rs' => 'rust',
    'go' => 'go',
    'py' => 'python',
    'rb' => 'ruby',
    'svg' => 'xml',
    'arb' => 'json',
    'lock' => 'yaml',
    _ => null,
  };
}

/// Human-readable language name for the details panel.
String languageDisplayName(String? languageId) {
  if (languageId == null) return 'Plain Text';

  return switch (languageId) {
    'dart' => 'Dart',
    'yaml' => 'YAML',
    'json' => 'JSON',
    'xml' => 'XML / HTML',
    'css' => 'CSS',
    'scss' => 'SCSS',
    'javascript' => 'JavaScript',
    'typescript' => 'TypeScript',
    'kotlin' => 'Kotlin',
    'java' => 'Java',
    'swift' => 'Swift',
    'gradle' => 'Gradle',
    'groovy' => 'Groovy',
    'bash' => 'Shell',
    'cmake' => 'CMake',
    'markdown' => 'Markdown',
    'sql' => 'SQL',
    'protobuf' => 'Protocol Buffers',
    'properties' => 'Properties',
    'ini' => 'INI / TOML',
    'c' => 'C',
    'cpp' => 'C++',
    'rust' => 'Rust',
    'go' => 'Go',
    'python' => 'Python',
    'ruby' => 'Ruby',
    _ => languageId,
  };
}