class TextSearchMatch {
  const TextSearchMatch({
    required this.line,
    required this.column,
    required this.length,
  });

  /// 1-based line number.
  final int line;

  /// 0-based column index in the line.
  final int column;
  final int length;
}

List<TextSearchMatch> findTextMatches(String content, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];

  final lowerQuery = trimmed.toLowerCase();
  final lines = content.split('\n');
  final matches = <TextSearchMatch>[];

  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    final line = lines[lineIndex];
    final lowerLine = line.toLowerCase();
    var start = 0;
    while (true) {
      final index = lowerLine.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(
        TextSearchMatch(
          line: lineIndex + 1,
          column: index,
          length: trimmed.length,
        ),
      );
      start = index + 1;
    }
  }

  return matches;
}
