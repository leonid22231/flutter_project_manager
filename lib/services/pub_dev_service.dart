import 'dart:convert';

import 'package:http/http.dart' as http;

class PubDevPackageInfo {
  const PubDevPackageInfo({
    this.latestVersion,
    this.description,
  });

  final String? latestVersion;
  final String? description;
}

class PubDevService {
  static const _baseUrl = 'https://pub.dev/api/packages';
  final Map<String, PubDevPackageInfo?> _cache = {};

  Future<PubDevPackageInfo?> fetchPackageInfo(String packageName) async {
    if (_cache.containsKey(packageName)) {
      return _cache[packageName];
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$packageName'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _cache[packageName] = null;
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = json['latest'] as Map<String, dynamic>?;
      final version = latest?['version'] as String?;
      final pubspec = latest?['pubspec'] as Map<String, dynamic>?;
      final description = pubspec?['description'] as String?;

      final info = PubDevPackageInfo(
        latestVersion: version,
        description: description?.trim().isEmpty ?? true ? null : description?.trim(),
      );
      _cache[packageName] = info;
      return info;
    } catch (_) {
      _cache[packageName] = null;
      return null;
    }
  }

  void clearCache() => _cache.clear();
}
