import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Renders Mermaid source to a raster image (PNG/JPEG).
///
/// Uses mermaid.ink `/img` (not SVG) because Mermaid SVGs contain
/// `foreignObject`/`filter`/`style` that flutter_svg cannot paint.
class MermaidRenderService {
  MermaidRenderService({http.Client? client}) : _client = client ?? http.Client();

  static final MermaidRenderService instance = MermaidRenderService();

  static const _krokiEndpoint = 'https://kroki.io/mermaid/png';
  static const _maxCacheEntries = 32;

  final http.Client _client;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List>> _inFlight = {};

  Future<Uint8List> renderImage(String source) {
    final normalized = _normalize(source);
    final cached = _cache[normalized];
    if (cached != null) return Future.value(cached);

    final existing = _inFlight[normalized];
    if (existing != null) return existing;

    final future = _fetchWithFallback(normalized);
    _inFlight[normalized] = future;
    return future.whenComplete(() => _inFlight.remove(normalized));
  }

  /// Legacy alias used by older call sites.
  Future<Uint8List> renderSvg(String source) => renderImage(source);

  Future<Uint8List> _fetchWithFallback(String source) async {
    Object? mermaidInkError;
    try {
      final bytes = await _fetchMermaidInk(source);
      _putCache(source, bytes);
      return bytes;
    } catch (e) {
      mermaidInkError = e;
    }

    try {
      final bytes = await _fetchKroki(source);
      _putCache(source, bytes);
      return bytes;
    } catch (e) {
      throw MermaidRenderException(
        'Mermaid render failed '
        '(mermaid.ink: $mermaidInkError; kroki: $e)',
      );
    }
  }

  Future<Uint8List> _fetchMermaidInk(String source) async {
    final encoded = base64UrlEncode(utf8.encode(source)).replaceAll('=', '');
    // Prefer PNG; fall back to default JPEG if PNG fails.
    final urls = [
      Uri.parse('https://mermaid.ink/img/$encoded?type=png&bgColor=1A1D24'),
      Uri.parse('https://mermaid.ink/img/$encoded?bgColor=1A1D24'),
    ];

    Object? lastError;
    for (final uri in urls) {
      try {
        final response =
            await _client.get(uri).timeout(const Duration(seconds: 25));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = MermaidRenderException(
            'mermaid.ink ${response.statusCode}: ${_shortBody(response.body)}',
          );
          continue;
        }
        final bytes = response.bodyBytes;
        if (!_looksLikeImage(bytes)) {
          lastError = const MermaidRenderException(
            'mermaid.ink response was not an image',
          );
          continue;
        }
        return bytes;
      } catch (e) {
        lastError = e;
      }
    }
    throw MermaidRenderException('$lastError');
  }

  Future<Uint8List> _fetchKroki(String source) async {
    final body = "%%{init: {'theme':'dark'}}%%\n$source";
    final response = await _client
        .post(
          Uri.parse(_krokiEndpoint),
          headers: const {
            'Content-Type': 'text/plain; charset=utf-8',
            'Accept': 'image/png',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MermaidRenderException(
        'Kroki ${response.statusCode}: ${_shortBody(response.body)}',
      );
    }
    final bytes = response.bodyBytes;
    if (!_looksLikeImage(bytes)) {
      throw const MermaidRenderException('Kroki response was not an image');
    }
    return bytes;
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    // WEBP (RIFF....WEBP)
    if (bytes.length > 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45) {
      return true;
    }
    return false;
  }

  String _shortBody(String body) {
    final trimmed = body.trim();
    if (trimmed.length <= 180) return trimmed;
    return '${trimmed.substring(0, 180)}…';
  }

  void _putCache(String key, Uint8List bytes) {
    _cache.remove(key);
    _cache[key] = bytes;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  String _normalize(String source) {
    var text = source.replaceAll('\r\n', '\n').trim();
    if (text.startsWith('```')) {
      final lines = text.split('\n');
      if (lines.isNotEmpty) lines.removeAt(0);
      if (lines.isNotEmpty && lines.last.trim().startsWith('```')) {
        lines.removeLast();
      }
      text = lines.join('\n').trim();
    }
    return text;
  }
}

class MermaidRenderException implements Exception {
  const MermaidRenderException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Heuristic: does this fenced code look like Mermaid?
bool looksLikeMermaidSource(String source) {
  final trimmed = source.trimLeft();
  if (trimmed.isEmpty) return false;
  final first = trimmed.split(RegExp(r'\r?\n')).first.trim().toLowerCase();
  const starters = [
    'flowchart',
    'graph ',
    'graph\t',
    'sequencediagram',
    'classdiagram',
    'statediagram',
    'erdiagram',
    'journey',
    'gantt',
    'pie',
    'mindmap',
    'timeline',
    'gitgraph',
    'quadrantchart',
    'requirementdiagram',
    'c4context',
    'block-beta',
    '%%{init',
  ];
  for (final s in starters) {
    if (first.startsWith(s)) return true;
  }
  if (RegExp(r'^graph\s*(td|lr|tb|rl)\b', caseSensitive: false)
      .hasMatch(first)) {
    return true;
  }
  return false;
}
