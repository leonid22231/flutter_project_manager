import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/zip_central_directory.dart';

void main() {
  test('listZipFilenames reads apk and aab from central directory', () {
    final archive = buildZipArchiveForTest({
      '25.0.0-1782982194.apk': 'apk',
      '25.0.0-1782982194.aab': 'aab',
    });

    final tail = archive.sublist(archive.length - 256);
    final info = findZipCentralDirectoryInfo(tail);
    expect(info, isNotNull);

    final centralDirectory = archive.sublist(info!.offset, info.offset + info.size);
    expect(
      parseZipCentralDirectoryFilenames(centralDirectory),
      ['25.0.0-1782982194.aab', '25.0.0-1782982194.apk'],
    );
  });

  test('listZipFilenames returns empty for invalid bytes', () {
    expect(listZipFilenames(const [1, 2, 3]), isEmpty);
  });
}
