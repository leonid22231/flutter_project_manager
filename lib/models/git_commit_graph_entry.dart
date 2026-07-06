class GitCommitGraphEntry {
  const GitCommitGraphEntry({
    required this.hash,
    required this.parents,
    required this.shortHash,
    required this.author,
    required this.email,
    required this.subject,
    this.committedAt,
    this.decorations,
  });

  final String hash;
  final List<String> parents;
  final String shortHash;
  final String author;
  final String email;
  final String subject;
  final DateTime? committedAt;
  final String? decorations;

  String get decorationsLabel {
    final value = decorations?.trim();
    if (value == null || value.isEmpty) return '';
    return value.replaceAll(RegExp(r'^\(|\)$'), '').trim();
  }
}

class GitCommitGraphRow {
  const GitCommitGraphRow({
    required this.entry,
    required this.lane,
    required this.laneCount,
    required this.activeLanes,
    required this.parentLanes,
  });

  final GitCommitGraphEntry entry;
  final int lane;
  final int laneCount;
  final Set<int> activeLanes;
  final List<int> parentLanes;
}

class GitCommitTreeNode {
  const GitCommitTreeNode({
    required this.entry,
    required this.parentNodes,
  });

  final GitCommitGraphEntry entry;
  final List<GitCommitTreeNode> parentNodes;

  bool get hasParents => parentNodes.isNotEmpty;
}

class GitCommitTreeRow {
  const GitCommitTreeRow({
    required this.entry,
    required this.depth,
    required this.ancestorContinues,
    required this.isLastSibling,
    required this.hasParents,
    required this.isExpanded,
  });

  final GitCommitGraphEntry entry;
  final int depth;
  final List<bool> ancestorContinues;
  final bool isLastSibling;
  final bool hasParents;
  final bool isExpanded;
}
