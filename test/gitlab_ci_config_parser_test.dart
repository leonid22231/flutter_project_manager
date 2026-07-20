import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/services/gitlab_ci_config_parser.dart';

void main() {
  test('parseGitLabCiBuildJobNames keeps only build stage jobs', () {
    const yaml = '''
stages:
  - pre_build
  - analyze_and_test
  - build

pre_build:
  stage: pre_build
  script:
    - flutter pub get

analyze:
  stage: analyze_and_test
  script:
    - flutter analyze

figma_test:
  stage: analyze_and_test
  script:
    - flutter test test/figma
  artifacts:
    paths:
      - coverage

.android_config: &android_config
  stage: build
  artifacts:
    paths:
      - ./*.apk

build_android_dev:
  <<: *android_config
  script:
    - flutter build apk
''';

    expect(
      parseGitLabCiBuildJobNames(yaml),
      {'build_android_dev'},
    );
  });

  test('parseGitLabCiBuildJobNames ignores jobs with explicit non-build stage', () {
    const yaml = '''
stages:
  - build

build_windows:
  stage: build
  script:
    - flutter build windows

test_job:
  stage: analyze_and_test
  script:
    - flutter test
  artifacts:
    paths:
      - coverage
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
