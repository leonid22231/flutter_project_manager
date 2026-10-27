class GitAuthorStats {
  const GitAuthorStats({
    required this.name,
    required this.email,
    required this.commits,
    required this.additions,
    required this.deletions,
  });

  final String name;
  final String email;
  final int commits;
  final int additions;
  final int deletions;
}

class GitWeekActivity {
  const GitWeekActivity({required this.weekStart, required this.commits});

  final DateTime weekStart;
  final int commits;
}

class GitRecentChange {
  const GitRecentChange({
    required this.shortHash,
    required this.author,
    required this.date,
    required this.subject,
  });

  final String shortHash;
  final String author;
  final String date;
  final String subject;
}

class GitProductivity {
  const GitProductivity({
    required this.since,
    required this.authors,
    required this.weeks,
    required this.recent,
    required this.commitCount,
    required this.additions,
    required this.deletions,
  });

  final DateTime since;
  final List<GitAuthorStats> authors;
  final List<GitWeekActivity> weeks;
  final List<GitRecentChange> recent;
  final int commitCount;
  final int additions;
  final int deletions;

  static const windowDays = 26 * 7;
  static const recentLimit = 8;
  static const authorLimit = 8;
}

const gitProductivityFieldSep = '\x1f';
const gitProductivityRecordSep = '\x1e';

/// Parses `git log --numstat --pretty=format:%x1e%an%x1f%ae%x1f%ad%x1f%h%x1f%s`.
GitProductivity parseGitProductivity(
  String output, {
  required DateTime since,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final start = _dateOnly(since);
  final commitsByAuthor = <String, _AuthorAccum>{};
  final commitsByWeek = <DateTime, int>{};
  final recent = <GitRecentChange>[];
  var commitCount = 0;
  var additions = 0;
  var deletions = 0;

  for (final record in output.split(gitProductivityRecordSep)) {
    final body = record.trim();
    if (body.isEmpty) continue;
    final lines = body.split('\n');
    final fields = lines.first.split(gitProductivityFieldSep);
    if (fields.length < 5) continue;
    final name = fields[0].trim();
    final email = fields[1].trim();
    final dateRaw = fields[2].trim();
    final shortHash = fields[3].trim();
    final subject = fields.sublist(4).join(gitProductivityFieldSep).trim();
    if (name.isEmpty && email.isEmpty) continue;

    final day = DateTime.tryParse(dateRaw);
    commitCount++;
    final key = email.isEmpty ? name.toLowerCase() : email.toLowerCase();
    final author = commitsByAuthor.putIfAbsent(
      key,
      () => _AuthorAccum(name: name, email: email),
    );
    if (name.isNotEmpty) author.name = name;
    author.commits++;

    if (day != null) {
      final week = _monday(_dateOnly(day));
      commitsByWeek[week] = (commitsByWeek[week] ?? 0) + 1;
    }

    var added = 0;
    var removed = 0;
    for (final line in lines.skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('\t');
      if (parts.length < 3) continue;
      final plus = int.tryParse(parts[0]);
      final minus = int.tryParse(parts[1]);
      if (plus != null) added += plus;
      if (minus != null) removed += minus;
    }
    author.additions += added;
    author.deletions += removed;
    additions += added;
    deletions += removed;

    if (recent.length < GitProductivity.recentLimit) {
      recent.add(
        GitRecentChange(
          shortHash: shortHash,
          author: name.isEmpty ? email : name,
          date: dateRaw,
          subject: subject,
        ),
      );
    }
  }

  final authors = commitsByAuthor.values.toList()
    ..sort((a, b) {
      final byCommits = b.commits.compareTo(a.commits);
      if (byCommits != 0) return byCommits;
      return b.additions.compareTo(a.additions);
    });

  final weeks = <GitWeekActivity>[];
  var cursor = _monday(start);
  final last = _monday(today);
  while (!cursor.isAfter(last)) {
    weeks.add(
      GitWeekActivity(
        weekStart: cursor,
        commits: commitsByWeek[cursor] ?? 0,
      ),
    );
    cursor = cursor.add(const Duration(days: 7));
  }

  return GitProductivity(
    since: start,
    authors: [
      for (final author in authors)
        GitAuthorStats(
          name: author.name,
          email: author.email,
          commits: author.commits,
          additions: author.additions,
          deletions: author.deletions,
        ),
    ],
    weeks: weeks,
    recent: recent,
    commitCount: commitCount,
    additions: additions,
    deletions: deletions,
  );
}

class _AuthorAccum {
  _AuthorAccum({required this.name, required this.email});

  String name;
  final String email;
  var commits = 0;
  var additions = 0;
  var deletions = 0;
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _monday(DateTime day) =>
    day.subtract(Duration(days: day.weekday - DateTime.monday));
