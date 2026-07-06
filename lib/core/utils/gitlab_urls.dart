String? buildGitLabCommitUrl(String? webUrl, String commitHash) {
  if (webUrl == null || webUrl.isEmpty) return null;
  return '$webUrl/-/commit/$commitHash';
}

String? buildGitLabFileHistoryUrl(
  String? webUrl,
  String? branch,
  String relativePath,
) {
  if (webUrl == null || webUrl.isEmpty) return null;
  final ref = (branch == null || branch.isEmpty) ? 'HEAD' : branch;
  final path = relativePath.replaceAll(r'\', '/');
  return '$webUrl/-/commits/$ref/$path';
}

String? buildGitLabNetworkUrl(String? webUrl, String? branch) {
  if (webUrl == null || webUrl.isEmpty) return null;
  final ref = (branch == null || branch.isEmpty) ? 'HEAD' : branch;
  return '$webUrl/-/network/$ref';
}

String? buildGitLabBlameUrl(
  String? webUrl,
  String? branch,
  String relativePath,
  int line,
) {
  if (webUrl == null || webUrl.isEmpty) return null;
  final ref = (branch == null || branch.isEmpty) ? 'HEAD' : branch;
  final path = relativePath.replaceAll(r'\', '/');
  return '$webUrl/-/blame/$ref/$path#L$line';
}
