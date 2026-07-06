class ProjectFileNode {
  const ProjectFileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.sizeBytes,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final List<ProjectFileNode> children;
  final int? sizeBytes;

  ProjectFileNode copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    List<ProjectFileNode>? children,
    int? sizeBytes,
  }) {
    return ProjectFileNode(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? this.children,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}
