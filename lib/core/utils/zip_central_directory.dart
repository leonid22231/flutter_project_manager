import 'dart:convert';
import 'dart:typed_data';

const _eocdSignature = 0x06054b50;
const _centralFileHeaderSignature = 0x02014b50;

class ZipCentralDirectoryInfo {
  const ZipCentralDirectoryInfo({
    required this.offset,
    required this.size,
    required this.totalEntries,
  });

  final int offset;
  final int size;
  final int totalEntries;
}

List<String> listZipFilenames(List<int> bytes) {
  final info = findZipCentralDirectoryInfo(bytes);
  if (info == null) return const [];

  final start = info.offset;
  final end = start + info.size;
  if (start < 0 || end > bytes.length) return const [];

  return parseZipCentralDirectoryFilenames(bytes.sublist(start, end));
}

ZipCentralDirectoryInfo? findZipCentralDirectoryInfo(List<int> bytes) {
  if (bytes.length < 22) return null;

  for (var index = bytes.length - 22; index >= 0; index--) {
    if (_readUint32(bytes, index) != _eocdSignature) continue;

    final size = _readUint32(bytes, index + 12);
    final offset = _readUint32(bytes, index + 16);
    final totalEntries = _readUint16(bytes, index + 10);
    if (size <= 0 || offset < 0) continue;

    return ZipCentralDirectoryInfo(
      offset: offset,
      size: size,
      totalEntries: totalEntries,
    );
  }

  return null;
}

List<String> parseZipCentralDirectoryFilenames(List<int> bytes) {
  final files = <String>[];
  var offset = 0;

  while (offset + 46 <= bytes.length) {
    if (_readUint32(bytes, offset) != _centralFileHeaderSignature) break;

    final nameLength = _readUint16(bytes, offset + 28);
    final extraLength = _readUint16(bytes, offset + 30);
    final commentLength = _readUint16(bytes, offset + 32);
    final nameStart = offset + 46;
    final nameEnd = nameStart + nameLength;

    if (nameEnd > bytes.length) break;

    final name = utf8.decode(bytes.sublist(nameStart, nameEnd));
    if (name.isNotEmpty) {
      files.add(name.replaceAll(r'\', '/'));
    }

    offset = nameEnd + extraLength + commentLength;
  }

  files.sort();
  return files;
}

bool zipTailContainsCentralDirectory(List<int> tail, ZipCentralDirectoryInfo info) {
  final end = info.offset + info.size;
  return info.offset >= 0 && end <= tail.length;
}

List<int> extractCentralDirectoryBytes(List<int> tail, ZipCentralDirectoryInfo info) {
  return tail.sublist(info.offset, info.offset + info.size);
}

int _readUint16(List<int> bytes, int offset) {
  return ByteData.sublistView(Uint8List.fromList(bytes)).getUint16(offset, Endian.little);
}

int _readUint32(List<int> bytes, int offset) {
  return ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(offset, Endian.little);
}

/// Builds a minimal zip archive bytes for tests.
List<int> buildZipArchiveForTest(Map<String, String> files) {
  final localParts = <int>[];
  final centralParts = <int>[];
  var offset = 0;

  void writeUint16(List<int> target, int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    target.addAll(data.buffer.asUint8List());
  }

  void writeUint32(List<int> target, int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    target.addAll(data.buffer.asUint8List());
  }

  void writeBytes(List<int> target, List<int> value) {
    target.addAll(value);
  }

  for (final entry in files.entries) {
    final nameBytes = utf8.encode(entry.key);
    final dataBytes = utf8.encode(entry.value);

    final localStart = localParts.length;

    writeUint32(localParts, 0x04034b50);
    writeUint16(localParts, 20);
    writeUint16(localParts, 0);
    writeUint16(localParts, 0);
    writeUint16(localParts, 0);
    writeUint16(localParts, 0);
    writeUint32(localParts, 0);
    writeUint32(localParts, dataBytes.length);
    writeUint32(localParts, dataBytes.length);
    writeUint16(localParts, nameBytes.length);
    writeUint16(localParts, 0);
    writeBytes(localParts, nameBytes);
    writeBytes(localParts, dataBytes);

    final localSize = localParts.length - localStart;

    writeUint32(centralParts, 0x02014b50);
    writeUint16(centralParts, 20);
    writeUint16(centralParts, 20);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint32(centralParts, 0);
    writeUint32(centralParts, dataBytes.length);
    writeUint32(centralParts, dataBytes.length);
    writeUint16(centralParts, nameBytes.length);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint16(centralParts, 0);
    writeUint32(centralParts, 0);
    writeUint32(centralParts, offset);
    writeBytes(centralParts, nameBytes);

    offset += localSize;
  }

  final centralOffset = localParts.length;
  final archive = <int>[...localParts, ...centralParts];

  writeUint32(archive, 0x06054b50);
  writeUint16(archive, 0);
  writeUint16(archive, 0);
  writeUint16(archive, files.length);
  writeUint16(archive, files.length);
  writeUint32(archive, centralParts.length);
  writeUint32(archive, centralOffset);
  writeUint16(archive, 0);

  return archive;
}
