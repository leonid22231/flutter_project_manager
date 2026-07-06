import 'package:project_manager/models/git_commit_graph_entry.dart';
import 'package:project_manager/services/git_service.dart';

List<GitCommitGraphEntry> parseGitLogGraphOutput(String output) {
  final entries = <GitCommitGraphEntry>[];
  for (final record in output.split(commitRecordSep)) {
    final trimmed = record.trim();
    if (trimmed.isEmpty) continue;

    final fields = trimmed.split(commitFieldSep);
    if (fields.length < 8) continue;

    final parents = fields[1]
        .split(RegExp(r'\s+'))
        .where((parent) => parent.isNotEmpty)
        .toList(growable: false);

    entries.add(
      GitCommitGraphEntry(
        hash: fields[0],
        parents: parents,
        shortHash: fields[2],
        author: fields[3],
        email: fields[4],
        committedAt: DateTime.tryParse(fields[5]),
        decorations: fields[6].trim().isEmpty ? null : fields[6].trim(),
        subject: fields[7],
      ),
    );
  }
  return entries;
}

List<GitCommitGraphRow> layoutGitCommitGraph(List<GitCommitGraphEntry> commits) {
  final rows = <GitCommitGraphRow>[];
  var lanes = <String?>[];

  for (final commit in commits) {
    final incomingLanes = <int>{
      for (var i = 0; i < lanes.length; i++)
        if (lanes[i] != null) i,
    };

    var lane = lanes.indexWhere((hash) => hash == commit.hash);
    if (lane == -1) {
      lane = lanes.indexWhere((hash) => hash == null);
      if (lane == -1) {
        lane = lanes.length;
      }
    }

    while (lanes.length <= lane) {
      lanes.add(null);
    }

    final parentLanes = <int>[];
    lanes[lane] = null;

    for (final parent in commit.parents) {
      var parentLane = lanes.indexWhere((hash) => hash == null);
      if (parentLane == -1) {
        parentLane = lanes.length;
        lanes.add(parent);
      } else {
        lanes[parentLane] = parent;
      }
      parentLanes.add(parentLane);
    }

    while (lanes.isNotEmpty && lanes.last == null) {
      lanes.removeLast();
    }

    final laneCount = [
      lanes.length,
      lane + 1,
      if (parentLanes.isNotEmpty) parentLanes.reduce((a, b) => a > b ? a : b) + 1,
    ].reduce((a, b) => a > b ? a : b);

    final activeLanes = <int>{...incomingLanes, ...parentLanes};
    activeLanes.remove(lane);

    rows.add(
      GitCommitGraphRow(
        entry: commit,
        lane: lane,
        laneCount: laneCount,
        activeLanes: activeLanes,
        parentLanes: parentLanes,
      ),
    );
  }

  return rows;
}

List<GitCommitTreeNode> buildGitCommitTree(List<GitCommitGraphEntry> commits) {
  if (commits.isEmpty) return const [];

  final byHash = {for (final commit in commits) commit.hash: commit};
  final order = {
    for (var index = 0; index < commits.length; index++) commits[index].hash: index,
  };
  final cache = <String, GitCommitTreeNode>{};

  GitCommitTreeNode nodeFor(String hash, Set<String> visiting) {
    final cached = cache[hash];
    if (cached != null) return cached;

    if (visiting.contains(hash)) {
      final entry = byHash[hash];
      if (entry == null) {
        throw StateError('Missing commit $hash');
      }
      return GitCommitTreeNode(entry: entry, parentNodes: const []);
    }

    final entry = byHash[hash];
    if (entry == null) {
      throw StateError('Missing commit $hash');
    }

    visiting.add(hash);
    final parentNodes = <GitCommitTreeNode>[];
    for (final parentHash in entry.parents) {
      if (byHash.containsKey(parentHash)) {
        parentNodes.add(nodeFor(parentHash, {...visiting}));
      }
    }
    visiting.remove(hash);

    parentNodes.sort(
      (a, b) => order[a.entry.hash]!.compareTo(order[b.entry.hash]!),
    );

    final node = GitCommitTreeNode(entry: entry, parentNodes: parentNodes);
    cache[hash] = node;
    return node;
  }

  final hasChild = <String>{};
  for (final commit in commits) {
    for (final parent in commit.parents) {
      hasChild.add(parent);
    }
  }

  final tips = commits.where((commit) => !hasChild.contains(commit.hash)).toList()
    ..sort((a, b) => order[a.hash]!.compareTo(order[b.hash]!));

  return [for (final tip in tips) nodeFor(tip.hash, {})];
}

Set<String> defaultExpandedGitCommitTree(List<GitCommitTreeNode> roots) {
  final expanded = <String>{};

  void expandMainLine(GitCommitTreeNode node) {
    expanded.add(node.entry.hash);
    if (node.parentNodes.isNotEmpty) {
      expandMainLine(node.parentNodes.first);
    }
  }

  for (final root in roots) {
    expanded.add(root.entry.hash);
    if (root.parentNodes.isNotEmpty) {
      expandMainLine(root.parentNodes.first);
    }
  }

  return expanded;
}

List<GitCommitTreeRow> flattenGitCommitTree(
  List<GitCommitTreeNode> roots,
  Set<String> expanded,
) {
  final rows = <GitCommitTreeRow>[];
  final displayed = <String>{};

  void walk(
    GitCommitTreeNode node,
    int depth,
    List<bool> ancestorContinues,
    bool isLastSibling,
  ) {
    if (displayed.contains(node.entry.hash)) {
      return;
    }
    displayed.add(node.entry.hash);

    final isNodeExpanded = expanded.contains(node.entry.hash);
    rows.add(
      GitCommitTreeRow(
        entry: node.entry,
        depth: depth,
        ancestorContinues: ancestorContinues,
        isLastSibling: isLastSibling,
        hasParents: node.hasParents,
        isExpanded: isNodeExpanded,
      ),
    );

    if (!isNodeExpanded) return;

    for (var index = 0; index < node.parentNodes.length; index++) {
      final parent = node.parentNodes[index];
      if (displayed.contains(parent.entry.hash)) continue;
      final isLast = index == node.parentNodes.length - 1;
      walk(
        parent,
        depth + 1,
        [...ancestorContinues, !isLastSibling],
        isLast,
      );
    }
  }

  for (var index = 0; index < roots.length; index++) {
    walk(roots[index], 0, const [], index == roots.length - 1);
  }

  return rows;
}

Set<String> collectGitCommitTreeHashes(List<GitCommitTreeNode> roots) {
  final hashes = <String>{};
  final visiting = <String>{};

  void collect(GitCommitTreeNode node) {
    if (visiting.contains(node.entry.hash)) return;
    visiting.add(node.entry.hash);
    hashes.add(node.entry.hash);
    for (final parent in node.parentNodes) {
      collect(parent);
    }
    visiting.remove(node.entry.hash);
  }

  for (final root in roots) {
    collect(root);
  }
  return hashes;
}
