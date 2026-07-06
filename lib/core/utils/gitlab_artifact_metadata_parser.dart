import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Parses GitLab Workhorse artifact metadata (metadata.gz).
/// Format: gzip containing length-prefixed UTF-8 strings (big-endian uint32).
/// Structure: version, errors JSON, then repeating (filename, entry metadata JSON).
List<String> parseGitLabArtifactMetadataGz(List<int> bytes) {
  if (bytes.isEmpty) return const [];

  try {
    final decoded = gzip.decode(bytes);
    if (decoded.length < 8) return const [];

    final reader = _LengthPrefixedStringReader(decoded);
    reader.readString(); // version
    reader.readString(); // errors

    final files = <String>[];
    while (reader.hasRemaining) {
      final filename = reader.readString();
      if (filename == null) break;
      final metadata = reader.readString();
      if (metadata == null) break;
      if (filename.isNotEmpty) {
        files.add(filename.replaceAll(r'\', '/'));
      }
    }

    files.sort();
    return files;
  } catch (_) {
    return const [];
  }
}

class _LengthPrefixedStringReader {
  _LengthPrefixedStringReader(List<int> bytes)
      : _bytes = bytes,
        _view = ByteData.sublistView(Uint8List.fromList(bytes));

  final List<int> _bytes;
  final ByteData _view;
  var _offset = 0;

  bool get hasRemaining => _offset < _bytes.length;

  String? readString() {
    if (_offset + 4 > _bytes.length) return null;

    final length = _view.getUint32(_offset, Endian.big);
    _offset += 4;
    if (_offset + length > _bytes.length) return null;

    final value = utf8.decode(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }
}

List<int> buildGitLabArtifactMetadataGzForTest(Map<String, String> entries) {
  return gzip.encode(_buildMetadataPayload(entries));
}

List<int> _buildMetadataPayload(Map<String, String> entries) {
  final payload = BytesBuilder();

  void writeString(String value) {
    final encoded = utf8.encode(value);
    final length = ByteData(4)..setUint32(0, encoded.length, Endian.big);
    payload.add(length.buffer.asUint8List());
    payload.add(encoded);
  }

  writeString('GitLab Build Artifacts Metadata 0.0.2\n');
  writeString('{}');
  for (final entry in entries.entries) {
    writeString(entry.key);
    writeString('${entry.value}\n');
  }

  return payload.toBytes();
}
