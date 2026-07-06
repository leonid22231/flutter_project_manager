import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:project_manager/models/global_package_metadata.dart';

class GlobalPackageMetadataService {
  static const _storageDirName = 'project_manager';
  static const _fileName = 'global_package_metadata.json';

  Map<String, GlobalPackageMetadata> _cache = {};
  bool _loaded = false;

  Future<Map<String, GlobalPackageMetadata>> loadAll() async {
    if (_loaded) return Map.unmodifiable(_cache);

    final file = await _getFile();
    if (!file.existsSync()) {
      _cache = {};
      _loaded = true;
      return {};
    }

    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _cache = json.map(
        (key, value) => MapEntry(
          key,
          GlobalPackageMetadata.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      _cache = {};
    }

    _loaded = true;
    return Map.unmodifiable(_cache);
  }

  GlobalPackageMetadata? getCached(String packageName) => _cache[packageName];

  Future<GlobalPackageMetadata> save(GlobalPackageMetadata metadata) async {
    await loadAll();
    _cache[metadata.packageName] = metadata.copyWith(
      updatedAt: DateTime.now(),
    );
    await _persist();
    return _cache[metadata.packageName]!;
  }

  Future<void> _persist() async {
    final file = await _getFile();
    final json = _cache.map((key, value) => MapEntry(key, value.toJson()));
    await file.writeAsString(jsonEncode(json));
  }

  Future<File> _getFile() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, _storageDirName));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File(p.join(dir.path, _fileName));
  }
}
