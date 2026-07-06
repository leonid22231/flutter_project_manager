enum MediaUsageReferenceKind {
  appAssetsConstant,
  appAssetsMethod,
  designedAssetCall,
  stringLiteral,
}

class MediaUsageEntry {
  const MediaUsageEntry({
    required this.filePath,
    required this.line,
    required this.snippet,
    required this.reference,
    required this.kind,
    this.resolvedPath,
  });

  final String filePath;
  final int line;
  final String snippet;
  final String reference;
  final MediaUsageReferenceKind kind;
  final String? resolvedPath;
}
