class GitCommitEntry {
  const GitCommitEntry({
    required this.hash,
    required this.shortHash,
    required this.author,
    required this.email,
    required this.subject,
    this.committedAt,
  });

  final String hash;
  final String shortHash;
  final String author;
  final String email;
  final String subject;
  final DateTime? committedAt;
}
