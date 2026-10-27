import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/services/context_sync_git_service.dart';
import 'package:project_manager/services/context_sync_service.dart';

void main() {
  test('git error text drops CRLF and filename warnings', () {
    const stderr = '''
warning: could not open directory 'video_player/platformview/': Filename too long
warning: in the working copy of 'KIOSK-668/context.json', LF will be replaced by CRLF the next time Git touches it
fatal: Unable to create index.lock
''';
    final text = contextSyncGitError(stderr, 1, 'add');
    expect(text, contains('fatal: Unable to create'));
    expect(text.toLowerCase(), isNot(contains('filename too long')));
    expect(text.toLowerCase(), isNot(contains('crlf')));
  });

  test('cursor merge is only for text context files', () {
    expect(contextSyncWantsCursorMerge(r'KIOSK-1\context.json'), isTrue);
    expect(contextSyncWantsCursorMerge('notes.md'), isTrue);
    expect(contextSyncWantsCursorMerge('KIOSK-1030/image.png'), isFalse);
    expect(contextSyncWantsCursorMerge('shot.jpg'), isFalse);
    expect(
      contextSyncWantsCursorMerge('video_player_android-2.9.4-backup.tar.gz'),
      isFalse,
    );
  });
}
