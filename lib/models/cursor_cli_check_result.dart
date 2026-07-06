class CursorCliCheckResult {
  const CursorCliCheckResult({
    required this.cliAvailable,
    this.version,
    this.authenticated,
    this.statusMessage,
    this.availableModels = const [],
    this.error,
  });

  final bool cliAvailable;
  final String? version;
  final bool? authenticated;
  final String? statusMessage;
  final List<String> availableModels;
  final String? error;

  bool get isSuccess =>
      cliAvailable && error == null && (authenticated ?? false);
}
