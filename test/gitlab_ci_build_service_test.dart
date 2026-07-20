import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/build_version_utils.dart';
import 'package:project_manager/services/gitlab_ci_config_parser.dart';

void main() {
  test('parseVersionFromBuildName extracts semver from artifact filename', () {
    expect(
      parseVersionFromBuildName('build/project_manager-1.2.3+45-windows.exe'),
      '1.2.3+45',
    );
    expect(
      parseVersionFromBuildName('app-release-2.0.1.apk'),
      '2.0.1',
    );
    expect(
      parseVersionFromBuildName('kiosk-3.4.5.678-release.apk'),
      '3.4.5.678',
    );
    expect(
      parseVersionFromBuildName('25.0.0-1782982194.apk'),
      '25.0.0-1782982194',
    );
    expect(
      parseVersionFromBuildName('fresh-dev_windows_25.0.0_1783671178.zip'),
      '25.0.0-1783671178',
    );
  });

  test('parseVersionFromBuildNames prefers release artifact filenames', () {
    expect(
      parseVersionFromBuildNames(const [
        'artifacts.zip',
        '25.0.0-1782982194.apk',
        '25.0.0-1782982194.aab',
      ]),
      '25.0.0-1782982194',
    );
    expect(
      parseVersionFromBuildNames(const [
        'artifacts.zip',
        'build/app-release-2.1.0+99.apk',
        'logs/output.txt',
      ]),
      '2.1.0+99',
    );
  });

  test('detectPlatformFromBuildContext uses job name and artifact paths', () {
    expect(
      detectPlatformFromBuildContext(
        jobName: 'build:windows',
        artifactPaths: const ['project_manager.exe'],
      ),
      'Windows',
    );
    expect(
      detectPlatformFromBuildContext(
        jobName: 'build apk',
        artifactPaths: const ['app-release.apk'],
      ),
      'Android',
    );
  });

  test('parseGitLabCiBuildJobNames finds jobs with artifacts section', () {
    const yaml = '''
stages:
  - build

build_windows:
  stage: build
  script:
    - flutter build windows
  artifacts:
    paths:
      - build/windows

test_job:
  stage: test
  script:
    - flutter test
''';

    expect(
      parseGitLabCiBuildJobNames(yaml),
      {'build_windows'},
    );
  });

  test('looksLikeCiBuildJobName matches common build job names', () {
    expect(looksLikeCiBuildJobName('build_windows', const {}), isTrue);
    expect(looksLikeCiBuildJobName('unit_tests', const {}), isFalse);
  });
}
