import 'package:project_manager/models/media_asset_binding.dart';
import 'package:project_manager/models/media_usage_entry.dart';

enum ProjectMediaKind {
  rasterImage,
  svg,
  font,
  other,
}

class ProjectMediaEntry {
  const ProjectMediaEntry({
    required this.path,
    required this.relativePath,
    required this.fileName,
    required this.folder,
    required this.kind,
    required this.sizeBytes,
    required this.declaredInPubspec,
    this.assetBindings = const [],
    this.usages = const [],
  });

  final String path;
  final String relativePath;
  final String fileName;
  final String folder;
  final ProjectMediaKind kind;
  final int sizeBytes;
  final bool declaredInPubspec;
  final List<MediaAssetBinding> assetBindings;
  final List<MediaUsageEntry> usages;

  bool get hasVisualPreview =>
      kind == ProjectMediaKind.rasterImage || kind == ProjectMediaKind.svg;

  int get usageCount => usages.length;
}
