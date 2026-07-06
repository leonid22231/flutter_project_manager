import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/services/project_media_service.dart';

void main() {
  test('parsePubspecDeclaredAssets reads flutter assets section', () {
    const pubspec = '''
name: demo
flutter:
  assets:
    - assets/images/
    - assets/icons/cart.png
''';

    final declared = parsePubspecDeclaredAssets(pubspec);

    expect(declared, {
      'assets/images/',
      'assets/icons/cart.png',
    });
  });

  test('isAssetPathDeclared matches files and directories', () {
    const pubspec = '''
flutter:
  assets:
    - assets/images/
    - assets/icons/cart.png
''';
    final declared = parsePubspecDeclaredAssets(pubspec);

    expect(
      isAssetPathDeclared('assets/images/logo.png', declared),
      isTrue,
    );
    expect(
      isAssetPathDeclared('assets/icons/cart.png', declared),
      isTrue,
    );
    expect(
      isAssetPathDeclared('assets/fonts/font.ttf', declared),
      isFalse,
    );
  });
}
