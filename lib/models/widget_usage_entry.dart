class WidgetUsageEntry {
  const WidgetUsageEntry({
    required this.filePath,
    required this.line,
    required this.snippet,
    this.enclosingName,
    this.positionalArgs = const [],
    this.namedArgs = const {},
  });

  final String filePath;
  final int line;
  final String snippet;
  final String? enclosingName;
  final List<String> positionalArgs;
  final Map<String, String> namedArgs;

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'line': line,
        'snippet': snippet,
        'enclosingName': enclosingName,
        'positionalArgs': positionalArgs,
        'namedArgs': namedArgs,
      };

  factory WidgetUsageEntry.fromJson(Map<String, dynamic> json) {
    return WidgetUsageEntry(
      filePath: json['filePath'] as String,
      line: json['line'] as int? ?? 0,
      snippet: json['snippet'] as String? ?? '',
      enclosingName: json['enclosingName'] as String?,
      positionalArgs: (json['positionalArgs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      namedArgs: (json['namedArgs'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
    );
  }
}
