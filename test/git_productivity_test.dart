import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/long_path.dart';
import 'package:project_manager/models/git_productivity.dart';

void main() {
  test('productivity parser sums authors, weeks, and recent commits', () {
    const output = '''
\x1eAda\x1fada@example.com\x1f2026-10-20\x1fabc1234\x1fLatest fix
10\t2\tlib/a.dart
-\t-\tassets/bin.dat
\x1eAda\x1fada@example.com\x1f2026-10-06\x1fdef5678\x1fEarlier
3\t1\tlib/b.dart
\x1eBen\x1fben@example.com\x1f2026-09-15\x1f999aaaa\x1fBen's change
1\t0\tREADME.md
''';

    final data = parseGitProductivity(
      output,
      since: DateTime(2026, 4, 28),
      now: DateTime(2026, 10, 27),
    );

    expect(data.commitCount, 3);
    expect(data.additions, 14);
    expect(data.deletions, 3);
    expect(data.authors.first.name, 'Ada');
    expect(data.authors.first.commits, 2);
    expect(data.authors.first.additions, 13);
    expect(data.authors[1].name, 'Ben');
    expect(data.recent.first.subject, 'Latest fix');
    expect(data.recent, hasLength(3));
    expect(data.weeks.any((week) => week.commits == 2), isFalse);
    expect(
      data.weeks.where((week) => week.commits > 0).length,
      3,
    );
  });

  test('walkFiles reads a file past the Windows path limit', () {
    final temp = Directory.systemTemp.createTempSync('pm_long_');
    addTearDown(() {
      if (temp.existsSync()) deleteTree(temp);
    });

    var dir = temp.path;
    while (dir.length < 250) {
      dir = p.join(dir, 'abcdefghij');
    }
    final nested = p.join(dir, 'platformview');
    longDir(nested).createSync(recursive: true);
    final note = p.join(nested, 'note.txt');
    expect(note.length, greaterThan(260));
    expect(
      () => windowsLongPath(note),
      returnsNormally,
    );
    expect(windowsLongPath(note).startsWith(r'\\?\'), isTrue);
    longFile(note).writeAsStringSync('hello');

    final found = <String, String>{};
    walkFiles(temp, (file, relative) {
      found[relative] = file.readAsStringSync();
    });

    expect(found.values, contains('hello'));
    expect(
      () => Directory(temp.path).listSync(recursive: true),
      throwsA(isA<FileSystemException>()),
    );
  }, skip: !Platform.isWindows);
}
