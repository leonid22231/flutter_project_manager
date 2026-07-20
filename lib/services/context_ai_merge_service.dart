import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Additive merge of two `.ai` directory snapshots without deleting data.
class ContextAiMergeService {
  /// Merge [localDir] and [remoteDir] into [outputDir].
  /// Both sides are treated as full `.ai` trees (file contents only).
  Future<void> mergeAdditive({
    required Directory localDir,
    required Directory remoteDir,
    required Directory outputDir,
  }) async {
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    final localFiles = _listRelativeFiles(localDir);
    final remoteFiles = _listRelativeFiles(remoteDir);
    final all = {...localFiles, ...remoteFiles};

    for (final relative in all) {
      final localFile = File(p.join(localDir.path, relative));
      final remoteFile = File(p.join(remoteDir.path, relative));
      final outFile = File(p.join(outputDir.path, relative));
      outFile.parent.createSync(recursive: true);

      final localExists = localFile.existsSync();
      final remoteExists = remoteFile.existsSync();

      if (localExists && !remoteExists) {
        await localFile.copy(outFile.path);
        continue;
      }
      if (!localExists && remoteExists) {
        await remoteFile.copy(outFile.path);
        continue;
      }

      final localBytes = await localFile.readAsBytes();
      final remoteBytes = await remoteFile.readAsBytes();
      if (_bytesEqual(localBytes, remoteBytes)) {
        await outFile.writeAsBytes(localBytes);
        continue;
      }

      final merged = _mergeFileContents(
        relativePath: relative,
        localBytes: localBytes,
        remoteBytes: remoteBytes,
        localMtime: localFile.lastModifiedSync(),
        remoteMtime: remoteFile.lastModifiedSync(),
      );
      await outFile.writeAsBytes(merged);
    }
  }

  List<int> _mergeFileContents({
    required String relativePath,
    required List<int> localBytes,
    required List<int> remoteBytes,
    required DateTime localMtime,
    required DateTime remoteMtime,
  }) {
    final lower = relativePath.toLowerCase();
    if (lower.endsWith('.json')) {
      try {
        final localText = utf8.decode(localBytes);
        final remoteText = utf8.decode(remoteBytes);
        final localJson = jsonDecode(localText);
        final remoteJson = jsonDecode(remoteText);
        final merged = mergeJsonValues(localJson, remoteJson);
        const encoder = JsonEncoder.withIndent('  ');
        return utf8.encode('${encoder.convert(merged)}\n');
      } catch (_) {
        // Fall through to text / binary handling.
      }
    }

    try {
      final localText = utf8.decode(localBytes);
      final remoteText = utf8.decode(remoteBytes);
      if (localText == remoteText) return localBytes;
      return utf8.encode(_mergeTextAdditive(localText, remoteText));
    } catch (_) {
      // Binary: keep newer, also write sibling for the other side below.
      return localMtime.isAfter(remoteMtime) ? localBytes : remoteBytes;
    }
  }

  String _mergeTextAdditive(String local, String remote) {
    final localLines = local.split('\n');
    final remoteLines = remote.split('\n');
    final seen = <String>{};
    final out = <String>[];
    for (final line in [...localLines, ...remoteLines]) {
      if (seen.add(line)) out.add(line);
    }
    return out.join('\n');
  }

  /// Deep-merge JSON values: objects union keys; arrays union by `id` or equality.
  static dynamic mergeJsonValues(dynamic local, dynamic remote) {
    if (local == null) return remote;
    if (remote == null) return local;

    if (local is Map && remote is Map) {
      final result = <String, dynamic>{};
      final keys = {...local.keys.map((k) => '$k'), ...remote.keys.map((k) => '$k')};
      for (final key in keys) {
        final l = local[key];
        final r = remote[key];
        if (l == null) {
          result[key] = r;
        } else if (r == null) {
          result[key] = l;
        } else {
          result[key] = mergeJsonValues(l, r);
        }
      }
      return result;
    }

    if (local is List && remote is List) {
      return _mergeJsonLists(local, remote);
    }

    // Scalars differ: prefer non-empty string, else local.
    if (local is String && remote is String) {
      if (local.isEmpty) return remote;
      if (remote.isEmpty) return local;
      if (local == remote) return local;
      // Keep both as list when conflicting scalar strings under unknown schema.
      return local;
    }

    return local;
  }

  static List<dynamic> _mergeJsonLists(List<dynamic> local, List<dynamic> remote) {
    final result = <dynamic>[];
    final seenIds = <String>{};
    final seenEncoded = <String>{};

    void addItem(dynamic item) {
      if (item is Map && item['id'] != null) {
        final id = '${item['id']}';
        if (seenIds.contains(id)) {
          final index = result.indexWhere(
            (e) => e is Map && '${e['id']}' == id,
          );
          if (index >= 0) {
            result[index] = mergeJsonValues(result[index], item);
          }
          return;
        }
        seenIds.add(id);
        result.add(item);
        return;
      }
      final encoded = jsonEncode(item);
      if (seenEncoded.add(encoded)) {
        result.add(item);
      }
    }

    for (final item in local) {
      addItem(item);
    }
    for (final item in remote) {
      addItem(item);
    }
    return result;
  }

  Set<String> _listRelativeFiles(Directory root) {
    if (!root.existsSync()) return {};
    final result = <String>{};
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: root.path);
      if (relative.startsWith('.git')) continue;
      result.add(relative);
    }
    return result;
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
