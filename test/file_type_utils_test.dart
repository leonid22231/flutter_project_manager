
import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/core/utils/file_type_utils.dart';

void main() {
  test('isPreviewableFontFile supports ttf and otf only', () {
    expect(isPreviewableFontFile('Roboto-Regular.ttf'), isTrue);
    expect(isPreviewableFontFile('Roboto-Regular.OTF'), isTrue);
    expect(isPreviewableFontFile('font.woff'), isFalse);
    expect(isPreviewableFontFile('font.woff2'), isFalse);
  });

  test('isFontFile includes web font extensions', () {
    expect(isFontFile('font.woff'), isTrue);
    expect(isFontFile('font.woff2'), isTrue);
  });
}
