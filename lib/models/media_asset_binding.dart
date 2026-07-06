class MediaAssetBinding {
  const MediaAssetBinding({
    required this.className,
    required this.constantName,
    required this.assetPath,
    required this.definitionFile,
    required this.definitionLine,
    this.inPreloadList = false,
    this.isDesigned = false,
    this.isMethod = false,
  });

  final String className;
  final String constantName;
  final String assetPath;
  final String definitionFile;
  final int definitionLine;
  final bool inPreloadList;
  final bool isDesigned;
  final bool isMethod;

  bool get isTemplate => assetPath.contains('{');

  String get reference => '$className.$constantName';
}
