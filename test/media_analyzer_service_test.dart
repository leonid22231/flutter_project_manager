import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/models/media_asset_binding.dart';
import 'package:project_manager/models/media_usage_entry.dart';
import 'package:project_manager/models/project_media_entry.dart';
import 'package:project_manager/services/media_analyzer_service.dart';
void main() {
  test('parseAssetsClassBindings reads AppAssets constants and preload list', () {
    const classBody = '''
  static const String iconTrash = 'assets/icons/cart_trash.svg';
  static const String iconTrash2 =
      'assets/icons/cart_trash.svg';
  static const List<String> localAssets = [
    iconTrash,
    iconTrash2,
  ];
''';

    final bindings = parseAssetsClassBindings(
      className: 'AppAssets',
      classBody: classBody,
      definitionFile: 'lib/core/app_assets.dart',
      classStartIndex: 0,
      fullContent: 'class AppAssets {$classBody}',
    );

    expect(bindings, hasLength(2));
    expect(bindings[0].reference, 'AppAssets.iconTrash');
    expect(bindings[0].assetPath, 'assets/icons/cart_trash.svg');
    expect(bindings[0].inPreloadList, isTrue);
    expect(bindings[1].reference, 'AppAssets.iconTrash2');
  });

  test('parseAssetsClassBindings supports AppAssetsDesigned filenames', () {
    const classBody = '''
  static String imagePromoStub = 'image_promo.png';
''';

    final bindings = parseAssetsClassBindings(
      className: 'AppAssetsDesigned',
      classBody: classBody,
      definitionFile: 'lib/core/app_assets.dart',
      classStartIndex: 0,
      fullContent: 'class AppAssetsDesigned {$classBody}',
    );

    expect(bindings, hasLength(1));
    expect(bindings.single.isDesigned, isTrue);
    expect(bindings.single.assetPath, 'image_promo.png');
  });

  test('parseAssetsClassBindings supports template paths and final fields', () {
    const classBody = '''
  static final String imageAsset = 'assets/flags/flag_{core}.png';
''';

    final bindings = parseAssetsClassBindings(
      className: 'AppAssets',
      classBody: classBody,
      definitionFile: 'lib/core/app_assets.dart',
      classStartIndex: 0,
      fullContent: 'class AppAssets {$classBody}',
    );

    expect(bindings, hasLength(1));
    expect(bindings.single.reference, 'AppAssets.imageAsset');
    expect(bindings.single.assetPath, 'assets/flags/flag_{core}.png');
    expect(bindings.single.isTemplate, isTrue);
  });

  test('matchesAssetTemplate links template bindings to concrete files', () {
    const template = 'assets/flags/flag_{core}.png';

    expect(matchesAssetTemplate(template, 'assets/flags/flag_ru.png'), isTrue);
    expect(matchesAssetTemplate(template, 'assets/flags/flag_en.png'), isTrue);
    expect(matchesAssetTemplate(template, 'assets/flags/flag.png'), isFalse);
    expect(matchesAssetTemplate(template, 'assets/icons/flag_ru.png'), isFalse);
  });

  test('attachAnalysis maps template usages to matching media files', () {
    final binding = MediaAssetBinding(
      className: 'AppAssets',
      constantName: 'imageAsset',
      assetPath: 'assets/flags/flag_{core}.png',
      definitionFile: 'lib/core/app_assets.dart',
      definitionLine: 2,
    );
    final usage = MediaUsageEntry(
      filePath: 'lib/widgets/flag.dart',
      line: 10,
      snippet: "Image.asset(AppAssets.imageAsset)",
      reference: 'AppAssets.imageAsset',
      kind: MediaUsageReferenceKind.appAssetsConstant,
      resolvedPath: binding.assetPath,
    );
    final analysis = MediaAnalysisResult(
      bindings: [binding],
      usagesByPath: {
        binding.assetPath: [usage],
      },
      designedUsagesByFileName: const {},
    );
    final entries = [
      ProjectMediaEntry(
        path: r'C:\proj\assets\flags\flag_ru.png',
        relativePath: 'assets/flags/flag_ru.png',
        fileName: 'flag_ru.png',
        folder: 'assets/flags',
        kind: ProjectMediaKind.rasterImage,
        sizeBytes: 100,
        declaredInPubspec: true,
      ),
      ProjectMediaEntry(
        path: r'C:\proj\assets\flags\flag_en.png',
        relativePath: 'assets/flags/flag_en.png',
        fileName: 'flag_en.png',
        folder: 'assets/flags',
        kind: ProjectMediaKind.rasterImage,
        sizeBytes: 100,
        declaredInPubspec: true,
      ),
    ];

    final enriched = MediaAnalyzerService().attachAnalysis(
      entries: entries,
      analysis: analysis,
    );

    expect(enriched[0].assetBindings.single.reference, 'AppAssets.imageAsset');
    expect(enriched[0].usageCount, 1);
    expect(enriched[1].assetBindings.single.reference, 'AppAssets.imageAsset');
    expect(enriched[1].usageCount, 1);
  });

  test('parseAssetsMethodBindings resolves interpolated switch return paths', () {
    const classBody = '''
  static const _iconsPath = 'assets/icons';

  static String? hallIconAsset(String hall) {
    return switch (_normalize(hall)) {
      'быстро' => '\$_iconsPath/fast.svg',
      _ => null,
    };
  }
''';

    final bindings = parseAssetsMethodBindings(
      className: 'AppAssets',
      classBody: classBody,
      definitionFile: 'lib/core/app_assets.dart',
      classStartIndex: 0,
      fullContent: 'class AppAssets {$classBody}',
    );

    expect(bindings, hasLength(1));
    expect(bindings.single.reference, 'AppAssets.hallIconAsset');
    expect(bindings.single.assetPath, 'assets/icons/fast.svg');
    expect(bindings.single.isMethod, isTrue);
  });

  test('parseMediaUsagesInFile detects AppAssets method calls', () {
    const classBody = '''
  static const _iconsPath = 'assets/icons';
  static String? hallIconAsset(String hall) {
    return '\$_iconsPath/fast.svg';
  }
''';
    final bindings = parseAssetsMethodBindings(
      className: 'AppAssets',
      classBody: classBody,
      definitionFile: 'lib/core/app_assets.dart',
      classStartIndex: 0,
      fullContent: 'class AppAssets {$classBody}',
    );

    final usages = parseMediaUsagesInFile(
      content: '''
Widget build(BuildContext context) {
  final icon = AppAssets.hallIconAsset(hall);
  return SvgPicture.asset(icon!);
}
''',
      relativePath: 'lib/demo.dart',
      bindingsByClass: {
        'AppAssets': {bindings.single.constantName: bindings.single},
      },
    );

    final methodUsages = usages
        .where((usage) => usage.kind == MediaUsageReferenceKind.appAssetsMethod)
        .toList();
    expect(methodUsages, hasLength(1));
    expect(methodUsages.single.reference, 'AppAssets.hallIconAsset');
  });

  test('attachAnalysis maps method usages to resolved asset files', () {
    final binding = MediaAssetBinding(
      className: 'AppAssets',
      constantName: 'hallIconAsset',
      assetPath: 'assets/icons/fast.svg',
      definitionFile: 'lib/core/app_assets.dart',
      definitionLine: 3,
      isMethod: true,
    );
    final usage = MediaUsageEntry(
      filePath: 'lib/widgets/hall.dart',
      line: 8,
      snippet: 'AppAssets.hallIconAsset(hall)',
      reference: 'AppAssets.hallIconAsset',
      kind: MediaUsageReferenceKind.appAssetsMethod,
    );
    final analysis = MediaAnalysisResult(
      bindings: [binding],
      usagesByPath: {
        binding.assetPath: [usage],
      },
      designedUsagesByFileName: const {},
    );
    final entries = [
      ProjectMediaEntry(
        path: r'C:\proj\assets\icons\fast.svg',
        relativePath: 'assets/icons/fast.svg',
        fileName: 'fast.svg',
        folder: 'assets/icons',
        kind: ProjectMediaKind.svg,
        sizeBytes: 100,
        declaredInPubspec: true,
      ),
    ];

    final enriched = MediaAnalyzerService().attachAnalysis(
      entries: entries,
      analysis: analysis,
    );

    expect(enriched.single.assetBindings.single.reference, 'AppAssets.hallIconAsset');
    expect(enriched.single.usageCount, 1);
  });

  test('parseMediaUsagesInFile finds AppAssets and designedAsset usages', () {
    final bindings = parseAssetsClassBindings(
      className: 'AppAssets',
      classBody:
          "static const String iconTrash = 'assets/icons/cart_trash.svg';",
      definitionFile: 'lib/core/app_assets.dart',
      classStartIndex: 0,
      fullContent:
          "class AppAssets { static const String iconTrash = 'assets/icons/cart_trash.svg'; }",
    );
    final designedBindings = parseAssetsClassBindings(
      className: 'AppAssetsDesigned',
      classBody: "static String imagePromoStub = 'image_promo.png';",
      definitionFile: 'lib/core/app_assets.dart',
      classStartIndex: 0,
      fullContent:
          "class AppAssetsDesigned { static String imagePromoStub = 'image_promo.png'; }",
    );

    final usages = parseMediaUsagesInFile(
      content: '''
class Demo {
  Widget build(BuildContext context) {
    return Image.asset(AppAssets.iconTrash);
  }
}

void load() {
  designedAsset(AppAssetsDesigned.imagePromoStub, brandSlug: 'basic');
}
''',
      relativePath: 'lib/demo.dart',
      bindingsByClass: {
        'AppAssets': {for (final b in bindings) b.constantName: b},
        'AppAssetsDesigned': {
          for (final b in designedBindings) b.constantName: b,
        },
      },
    );

    expect(
      usages.where((usage) => usage.reference == 'AppAssets.iconTrash'),
      hasLength(1),
    );
    expect(
      usages.where(
        (usage) => usage.kind == MediaUsageReferenceKind.designedAssetCall,
      ),
      hasLength(1),
    );
    expect(
      usages.any((usage) => usage.reference.contains('imagePromoStub')),
      isTrue,
    );
  });
}
