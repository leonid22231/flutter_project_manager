import 'dart:convert';
import 'dart:io';

/// UTF-8 file helpers.
///
/// On Windows, [File.readAsString] / [writeAsString] default to
/// [systemEncoding], which corrupts Cyrillic JSON written as UTF-8
/// (classic `Ð¿Ð¾Ð²Ñ‚Ð¾Ñ€Ð½Ð¾` mojibake). Always use these helpers for `.ai` JSON.
Future<String> readUtf8File(File file) => file.readAsString(encoding: utf8);

String readUtf8FileSync(File file) => file.readAsStringSync(encoding: utf8);

Future<void> writeUtf8File(
  File file,
  String contents, {
  FileMode mode = FileMode.write,
  bool flush = false,
}) {
  return file.writeAsString(
    contents,
    encoding: utf8,
    mode: mode,
    flush: flush,
  );
}

void writeUtf8FileSync(
  File file,
  String contents, {
  FileMode mode = FileMode.write,
  bool flush = false,
}) {
  file.writeAsStringSync(
    contents,
    encoding: utf8,
    mode: mode,
    flush: flush,
  );
}

/// Detects UTF-8 bytes that were decoded as Latin-1 / Windows-1252.
bool looksLikeUtf8Mojibake(String input) {
  if (input.isEmpty) return false;
  // Typical markers: Ð/Ñ/Ã plus CP1252 punctuation from UTF-8 continuations.
  final markers = RegExp(
    r'[ÐÑÃ][\u0080-\u00FF\u0152\u0153\u0160\u0161\u0178\u017D\u017E'
    r'\u0192\u02C6\u02DC\u2013\u2014\u2018-\u201E\u2020-\u2022\u2026'
    r'\u2030\u2039\u203A\u20AC\u2122]',
  );
  final matches = markers.allMatches(input).length;
  if (matches < 2) return false;
  final ratio = matches / (input.length.clamp(1, 100000));
  return ratio > 0.02 || matches >= 3;
}

/// Maps a Unicode code point produced by a Windows-1252 decode back to a byte.
int? _windows1252Byte(int codeUnit) {
  if (codeUnit <= 0xFF) return codeUnit;
  const map = <int, int>{
    0x20AC: 0x80, // €
    0x201A: 0x82, // ‚
    0x0192: 0x83, // ƒ
    0x201E: 0x84, // „
    0x2026: 0x85, // …
    0x2020: 0x86, // †
    0x2021: 0x87, // ‡
    0x02C6: 0x88, // ˆ
    0x2030: 0x89, // ‰
    0x0160: 0x8A, // Š
    0x2039: 0x8B, // ‹
    0x0152: 0x8C, // Œ
    0x017D: 0x8E, // Ž
    0x2018: 0x91, // ‘
    0x2019: 0x92, // ’
    0x201C: 0x93, // “
    0x201D: 0x94, // ”
    0x2022: 0x95, // •
    0x2013: 0x96, // –
    0x2014: 0x97, // —
    0x02DC: 0x98, // ˜
    0x2122: 0x99, // ™
    0x0161: 0x9A, // š
    0x203A: 0x9B, // ›
    0x0153: 0x9C, // œ
    0x017E: 0x9E, // ž
    0x0178: 0x9F, // Ÿ
  };
  return map[codeUnit];
}

/// Repairs mojibake: Windows-1252/Latin-1 view of UTF-8 bytes → Unicode.
String repairUtf8Mojibake(String input) {
  if (!looksLikeUtf8Mojibake(input)) return input;
  final bytes = <int>[];
  for (final unit in input.codeUnits) {
    final b = _windows1252Byte(unit);
    if (b == null) return input;
    bytes.add(b);
  }
  try {
    final repaired = utf8.decode(bytes);
    if (repaired == input) return input;
    final beforeCyr = RegExp(r'[\u0400-\u04FF]').allMatches(input).length;
    final afterCyr = RegExp(r'[\u0400-\u04FF]').allMatches(repaired).length;
    final beforeJunk = RegExp(r'[ÐÑÃ]').allMatches(input).length;
    final afterJunk = RegExp(r'[ÐÑÃ]').allMatches(repaired).length;
    if (afterCyr > beforeCyr || afterJunk < beforeJunk) {
      return repaired;
    }
  } catch (_) {}
  return input;
}

/// Deep-repair string values in JSON-compatible structures.
dynamic repairUtf8InJson(dynamic value) {
  if (value is String) return repairUtf8Mojibake(value);
  if (value is List) {
    return value.map(repairUtf8InJson).toList(growable: false);
  }
  if (value is Map) {
    return value.map((key, v) {
      final k = key is String ? repairUtf8Mojibake(key) : key;
      return MapEntry(k, repairUtf8InJson(v));
    });
  }
  return value;
}
