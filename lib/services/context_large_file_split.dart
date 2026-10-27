import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:project_manager/core/utils/long_path.dart';

/// A split file as it sits in the git clone: parts plus a manifest.
class SplitCatalog {
  const SplitCatalog({required this.skip, required this.virtuals});

  /// Part files and manifests. They stand in for the original file.
  final Set<String> skip;

  /// Original relative path and the manifest that describes its parts.
  final List<({String relative, File manifest})> virtuals;

  static const empty = SplitCatalog(skip: {}, virtuals: []);
}

/// GitHub rejects a blob at or above 100 MiB. Parts stay under that limit.
class ContextLargeFileSplit {
  ContextLargeFileSplit._();

  static const githubLimitBytes = 100 * 1024 * 1024;
  static const partBytes = 95 * 1024 * 1024;

  static String manifestNameFor(String fileName) => '$fileName.pm-split.json';

  static String partNameFor(String fileName, int index) =>
      '${fileName}_part_$index';

  static final Map<String, String> _signatureCache = {};

  /// Lists part files so a diff can compare them to the original file
  /// without writing that file back to disk.
  static SplitCatalog catalog(Directory root) {
    if (!root.existsSync()) return SplitCatalog.empty;
    final skip = <String>{};
    final virtuals = <({String relative, File manifest})>[];
    walkFiles(root, (file, relative) {
      if (!p.basename(relative).endsWith('.pm-split.json')) return;
      final decoded = _readManifest(file);
      if (decoded == null) return;
      final originalName = p.basename(relative).replaceFirst(
            '.pm-split.json',
            '',
          );
      final dirRel = p.dirname(relative);
      final originalRel =
          dirRel == '.' ? originalName : p.join(dirRel, originalName);
      final partRels = <String>[];
      for (var index = 1; index <= decoded.parts; index++) {
        final partRel = dirRel == '.'
            ? partNameFor(originalName, index)
            : p.join(dirRel, partNameFor(originalName, index));
        final part = longFile(p.join(plainAbsolute(root.path), partRel));
        if (!part.existsSync()) return;
        partRels.add(partRel);
      }
      skip.add(relative);
      skip.addAll(partRels);
      virtuals.add((relative: originalRel, manifest: file));
    }, skipGit: true);
    return SplitCatalog(skip: skip, virtuals: virtuals);
  }

  /// `split:<bytes>:<sha256>` for a whole file.
  static Future<String> fileSignature(File file) async {
    final length = file.lengthSync();
    final mtime = file.lastModifiedSync().millisecondsSinceEpoch;
    final key = '${plainAbsolute(file.path)}|$length|$mtime';
    final cached = _signatureCache[key];
    if (cached != null) return cached;
    final digest = await _hashStream(file.openRead());
    final value = 'split:$length:$digest';
    _signatureCache[key] = value;
    return value;
  }

  /// Same signature as [fileSignature] for the file the manifest describes.
  static Future<String> partsSignature(File manifest) async {
    final decoded = _readManifest(manifest);
    if (decoded == null) return 'split:0:missing';
    if (decoded.sha256 != null && decoded.sha256!.isNotEmpty) {
      return 'split:${decoded.bytes}:${decoded.sha256}';
    }
    final mtime = manifest.lastModifiedSync().millisecondsSinceEpoch;
    final key = '${plainAbsolute(manifest.path)}|${decoded.bytes}|$mtime';
    final cached = _signatureCache[key];
    if (cached != null) return cached;
    final dir = p.dirname(plainAbsolute(manifest.path));
    final originalName = p.basename(manifest.path).replaceFirst(
          '.pm-split.json',
          '',
        );
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    for (var index = 1; index <= decoded.parts; index++) {
      final part = longFile(p.join(dir, partNameFor(originalName, index)));
      await for (final chunk in part.openRead()) {
        input.add(chunk);
      }
    }
    input.close();
    final value = 'split:${decoded.bytes}:${sink.value}';
    _signatureCache[key] = value;
    return value;
  }

  /// Replaces each file at or above [limitBytes] with `name_part_1` …
  /// and a small `name.pm-split.json`.
  static Future<int> splitInPlace(
    Directory root, {
    int limitBytes = githubLimitBytes,
    int chunkBytes = partBytes,
  }) async {
    if (!root.existsSync() || chunkBytes <= 0) return 0;
    final large = <(File, String)>[];
    walkFiles(root, (file, relative) {
      if (_isSplitArtifact(relative)) return;
      try {
        if (file.lengthSync() >= limitBytes) large.add((file, relative));
      } catch (_) {}
    }, skipGit: true);
    var split = 0;
    for (final entry in large) {
      await _splitOne(
        entry.$1,
        chunkBytes: chunkBytes,
      );
      split++;
    }
    return split;
  }

  /// Rebuilds original files from parts and removes the part files.
  static Future<int> joinInPlace(Directory root) async {
    if (!root.existsSync()) return 0;
    final manifests = <(File, String)>[];
    walkFiles(root, (file, relative) {
      if (p.basename(relative).endsWith('.pm-split.json')) {
        manifests.add((file, relative));
      }
    }, skipGit: true);
    var joined = 0;
    for (final entry in manifests) {
      if (await _joinOne(entry.$1)) joined++;
    }
    return joined;
  }

  static bool _isSplitArtifact(String relative) {
    final name = p.basename(relative);
    if (name.endsWith('.pm-split.json')) return true;
    return RegExp(r'_part_\d+$').hasMatch(name);
  }

  static Future<void> _splitOne(
    File source, {
    required int chunkBytes,
  }) async {
    final length = source.lengthSync();
    final name = p.basename(source.path);
    final dir = p.dirname(plainAbsolute(source.path));
    final partCount = (length / chunkBytes).ceil();
    final hashSink = _DigestSink();
    final hash = sha256.startChunkedConversion(hashSink);
    for (var index = 1; index <= partCount; index++) {
      final start = (index - 1) * chunkBytes;
      final end = math.min(start + chunkBytes, length);
      final part = longFile(p.join(dir, partNameFor(name, index)));
      final sink = part.openWrite();
      await for (final chunk in source.openRead(start, end)) {
        hash.add(chunk);
        sink.add(chunk);
      }
      await sink.close();
    }
    hash.close();
    final manifest = longFile(p.join(dir, manifestNameFor(name)));
    manifest.writeAsStringSync(
      jsonEncode({
        'parts': partCount,
        'bytes': length,
        'sha256': '${hashSink.value}',
      }),
    );
    source.deleteSync();
  }

  static Future<bool> _joinOne(File manifest) async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }
    final parts = json['parts'];
    if (parts is! int || parts <= 0) return false;
    final dir = p.dirname(plainAbsolute(manifest.path));
    final originalName = p.basename(manifest.path).replaceFirst(
          '.pm-split.json',
          '',
        );
    final sources = <File>[];
    for (var index = 1; index <= parts; index++) {
      final part = longFile(p.join(dir, partNameFor(originalName, index)));
      if (!part.existsSync()) return false;
      sources.add(part);
    }
    final target = longFile(p.join(dir, originalName));
    final sink = target.openWrite();
    for (final part in sources) {
      await sink.addStream(part.openRead());
    }
    await sink.close();
    for (final part in sources) {
      part.deleteSync();
    }
    manifest.deleteSync();
    return true;
  }

  static _ManifestData? _readManifest(File manifest) {
    try {
      final json = jsonDecode(manifest.readAsStringSync());
      if (json is! Map) return null;
      final parts = json['parts'];
      final bytes = json['bytes'];
      if (parts is! int || parts <= 0) return null;
      if (bytes is! int || bytes < 0) return null;
      final sha = json['sha256'];
      return _ManifestData(
        parts: parts,
        bytes: bytes,
        sha256: sha is String ? sha : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> _hashStream(Stream<List<int>> stream) async {
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    await for (final chunk in stream) {
      input.add(chunk);
    }
    input.close();
    return '${sink.value}';
  }
}

class _ManifestData {
  const _ManifestData({
    required this.parts,
    required this.bytes,
    this.sha256,
  });

  final int parts;
  final int bytes;
  final String? sha256;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
