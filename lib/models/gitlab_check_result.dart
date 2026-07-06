class GitLabCheckResult {
  const GitLabCheckResult({
    required this.connected,
    this.username,
    this.error,
  });

  final bool connected;
  final String? username;
  final String? error;
}
