class GitLabPaginationInfo {
  const GitLabPaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    this.headerDump = '',
  });

  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final String headerDump;
}

GitLabPaginationInfo parseGitLabPagination({
  required Map<String, String> headers,
  required int requestedPage,
  required int requestedPerPage,
  required int rawItemCount,
}) {
  final normalized = <String, String>{};
  headers.forEach((key, value) {
    normalized[key.toLowerCase()] = value;
  });

  int? readInt(String key) => int.tryParse(normalized[key] ?? '');

  var currentPage = readInt('x-page') ?? requestedPage;
  var totalPages = readInt('x-total-pages');
  final total = readInt('x-total');
  final perPage = readInt('x-per-page') ?? requestedPerPage;
  final link = normalized['link'];

  if (totalPages == null && total != null && perPage > 0) {
    totalPages = (total + perPage - 1) ~/ perPage;
  }

  final lastPageFromLink = pageFromGitLabLinkRelation(link, 'last');
  if (lastPageFromLink != null) {
    totalPages = lastPageFromLink;
  }

  totalPages ??= currentPage;

  var hasNext = gitLabLinkHasRelation(link, 'next');
  if (!hasNext && totalPages > currentPage) {
    hasNext = true;
  }
  if (!hasNext && rawItemCount >= requestedPerPage) {
    hasNext = true;
  }

  final nextPageHeader = normalized['x-next-page']?.trim();
  if (nextPageHeader != null && nextPageHeader.isNotEmpty) {
    final nextPage = int.tryParse(nextPageHeader);
    if (nextPage != null && nextPage > currentPage) {
      hasNext = true;
      if (totalPages < nextPage) totalPages = nextPage;
    }
  }

  final headerDump = normalized.entries
      .where((entry) {
        final key = entry.key;
        return key.startsWith('x-') || key == 'link';
      })
      .map((entry) => '${entry.key}=${entry.value}')
      .join('; ');

  return GitLabPaginationInfo(
    currentPage: currentPage,
    totalPages: totalPages,
    hasNextPage: hasNext,
    headerDump: headerDump,
  );
}

bool gitLabLinkHasRelation(String? link, String rel) {
  if (link == null || link.isEmpty) return false;
  final pattern = RegExp(
    r'<[^>]+>\s*;\s*rel="' + RegExp.escape(rel) + r'"',
  );
  return pattern.hasMatch(link);
}

int? pageFromGitLabLinkRelation(String? link, String rel) {
  if (link == null || link.isEmpty) return null;
  final pattern = RegExp(
    r'<([^>]+)>\s*;\s*rel="' + RegExp.escape(rel) + r'"',
  );
  final match = pattern.firstMatch(link);
  if (match == null) return null;
  final uri = Uri.tryParse(match.group(1)!);
  return int.tryParse(uri?.queryParameters['page'] ?? '');
}
