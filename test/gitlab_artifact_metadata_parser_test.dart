import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/gitlab_artifact_metadata_parser.dart';

void main() {
  test('parseGitLabArtifactMetadataGz extracts filenames from metadata', () {
    final metadata = buildGitLabArtifactMetadataGzForTest({
      '25.0.0-1782982194.apk': '{"crc":123}',
      '25.0.0-1782982194.aab': '{"crc":456}',
    });

    expect(
      parseGitLabArtifactMetadataGz(metadata),
      ['25.0.0-1782982194.aab', '25.0.0-1782982194.apk'],
    );
  });
}
