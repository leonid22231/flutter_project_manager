import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/services/context_large_file_split.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pm_split_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('split and join restore the original bytes', () async {
    final source = File('${temp.path}\\installed.apk');
    final original = List<int>.generate(10, (i) => i + 1);
    source.writeAsBytesSync(original);

    final split = await ContextLargeFileSplit.splitInPlace(
      temp,
      limitBytes: 10,
      chunkBytes: 4,
    );
    expect(split, 1);
    expect(source.existsSync(), isFalse);
    expect(File('${temp.path}\\installed.apk_part_1').lengthSync(), 4);
    expect(File('${temp.path}\\installed.apk_part_2').lengthSync(), 4);
    expect(File('${temp.path}\\installed.apk_part_3').lengthSync(), 2);
    expect(
      File('${temp.path}\\installed.apk.pm-split.json').existsSync(),
      isTrue,
    );

    final joined = await ContextLargeFileSplit.joinInPlace(temp);
    expect(joined, 1);
    expect(source.readAsBytesSync(), original);
    expect(File('${temp.path}\\installed.apk_part_1').existsSync(), isFalse);
    expect(
      File('${temp.path}\\installed.apk.pm-split.json').existsSync(),
      isFalse,
    );
  });

  test('a file under the limit stays whole', () async {
    final source = File('${temp.path}\\note.txt');
    source.writeAsStringSync('hello');

    final split = await ContextLargeFileSplit.splitInPlace(
      temp,
      limitBytes: 10,
      chunkBytes: 4,
    );
    expect(split, 0);
    expect(source.readAsStringSync(), 'hello');
  });

  test('files inside .git are not split', () async {
    final git = Directory('${temp.path}\\.git')..createSync();
    final pack = File('${git.path}\\pack.bin');
    pack.writeAsBytesSync(List<int>.filled(20, 7));
    final kept = File('${temp.path}\\installed.apk');
    kept.writeAsBytesSync(List<int>.filled(20, 3));

    await ContextLargeFileSplit.splitInPlace(
      temp,
      limitBytes: 10,
      chunkBytes: 4,
    );

    expect(pack.existsSync(), isTrue);
    expect(pack.lengthSync(), 20);
    expect(kept.existsSync(), isFalse);
    expect(File('${temp.path}\\installed.apk_part_1').existsSync(), isTrue);
  });

  test('part signature matches the original file without joining', () async {
    final source = File('${temp.path}\\installed.apk');
    final original = List<int>.generate(10, (i) => i + 1);
    source.writeAsBytesSync(original);
    final before = await ContextLargeFileSplit.fileSignature(source);

    await ContextLargeFileSplit.splitInPlace(
      temp,
      limitBytes: 10,
      chunkBytes: 4,
    );
    final catalog = ContextLargeFileSplit.catalog(temp);
    expect(catalog.virtuals, hasLength(1));
    expect(catalog.virtuals.single.relative, 'installed.apk');
    expect(catalog.skip, contains('installed.apk_part_1'));
    expect(source.existsSync(), isFalse);

    final remote =
        await ContextLargeFileSplit.partsSignature(catalog.virtuals.single.manifest);
    expect(remote, before);
  });
}
