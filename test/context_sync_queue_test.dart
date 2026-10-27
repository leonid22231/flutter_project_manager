import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/context_sync_status.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/global_package_metadata.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/context_sync_service.dart';
import 'package:project_manager/services/global_package_metadata_service.dart';
import 'package:project_manager/services/project_storage_service.dart';
import 'package:project_manager/services/settings_service.dart';
import 'package:project_manager/state/project_manager_state.dart';

const _contextA = '11111111-1111-4111-8111-111111111111';
const _contextB = '22222222-2222-4222-8222-222222222222';

void main() {
  late Directory temp;
  late _RecordingSync sync;
  late ProjectManagerState state;
  late Project projectA;
  late Project projectB;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pm_sync_queue_');
    final dirA = Directory('${temp.path}\\a')..createSync();
    final dirB = Directory('${temp.path}\\b')..createSync();
    File('${dirA.path}\\pubspec.yaml').writeAsStringSync('name: a\n');
    File('${dirB.path}\\pubspec.yaml').writeAsStringSync('name: b\n');
    projectA = _project('p1', _contextA, dirA.path);
    projectB = _project('p2', _contextB, dirB.path);
    sync = _RecordingSync();
    state = _stateFor([projectA, projectB], sync);
    state.debugPostSyncSuppress = Duration.zero;
    state.setProjectsForTest([projectA, projectB], selected: projectA);
  });

  tearDown(() async {
    state.dispose();
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });

  test('second project starts only after the first finishes', () async {
    final firstRunning = Completer<void>();
    final releaseFirst = Completer<void>();
    final order = <String>[];

    sync.onSync = (project, _) async {
      order.add('start:${project.id}');
      if (project.id == projectA.id) {
        firstRunning.complete();
        await releaseFirst.future;
      }
      order.add('end:${project.id}');
      return _ok(project);
    };

    final queue = state.runContextSyncAllForTest('interval');
    await firstRunning.future;
    expect(order, ['start:p1']);
    expect(sync.maxInFlight, 1);

    releaseFirst.complete();
    await queue;

    expect(order, ['start:p1', 'end:p1', 'start:p2', 'end:p2']);
    expect(sync.maxInFlight, 1);
    expect(sync.ids, ['p1', 'p2']);
  });

  test('interval is not limited by the one-shot auto cursor sync', () async {
    sync.onSync = (project, _) async => _ok(project);

    await state.runContextSyncForTest(reason: 'project-selected');
    expect(state.autoCursorSyncDoneForTest(projectA.id), isTrue);
    expect(sync.ids, ['p1']);

    state.debugClearSyncCooldown();
    sync.ids.clear();

    await state.runContextSyncAllForTest('interval');

    expect(sync.ids, ['p1', 'p2']);
    expect(state.autoCursorSyncDoneForTest(projectA.id), isTrue);
    expect(state.autoCursorSyncDoneForTest(projectB.id), isFalse);
  });

  test('a second queue call while one is running does not start another', () async {
    final firstRunning = Completer<void>();
    final releaseFirst = Completer<void>();
    sync.onSync = (project, _) async {
      if (project.id == projectA.id && !firstRunning.isCompleted) {
        firstRunning.complete();
        await releaseFirst.future;
      }
      return _ok(project);
    };

    final first = state.runContextSyncAllForTest('startup');
    await firstRunning.future;
    final second = state.runContextSyncAllForTest('interval');
    expect(identical(first, second), isTrue);

    releaseFirst.complete();
    await first;
    expect(sync.ids, ['p1', 'p2']);
  });

  test('startup queue keeps going after the selected project changes', () async {
    final firstRunning = Completer<void>();
    final releaseFirst = Completer<void>();
    bool? stillGoing;
    sync.onSync = (project, shouldContinue) async {
      if (project.id == projectA.id && !firstRunning.isCompleted) {
        firstRunning.complete();
        await releaseFirst.future;
        stillGoing = shouldContinue?.call();
      }
      return _ok(project);
    };

    final queue = state.runContextSyncAllForTest('startup');
    await firstRunning.future;
    state.debugDetachSelection(projectB);
    releaseFirst.complete();
    await queue;

    expect(stillGoing, isTrue);
    expect(sync.ids, ['p1', 'p2']);
  });

  test('project switch still cancels a selection-armed sync', () async {
    final running = Completer<void>();
    final release = Completer<void>();
    bool? stillGoing;
    sync.onSync = (project, shouldContinue) async {
      running.complete();
      await release.future;
      stillGoing = shouldContinue?.call();
      if (stillGoing == false) {
        return const ContextSyncStatus(
          phase: ContextSyncPhase.idle,
          message: 'Sync cancelled',
        );
      }
      return _ok(project);
    };

    final syncing = state.runContextSyncForTest(reason: 'project-selected');
    await running.future;
    state.debugDetachSelection(projectB);
    release.complete();
    await syncing;

    expect(stillGoing, isFalse);
    expect(state.autoCursorSyncDoneForTest(projectA.id), isFalse);
  });

  test('manual sync still runs only the selected project', () async {
    sync.onSync = (project, _) async => _ok(project);
    state.setProjectsForTest([projectA, projectB], selected: projectB);

    await state.syncContextNow();

    expect(sync.ids, ['p2']);
  });

  test('network pull failure backs off three times then stops the pass', () async {
    final delays = <Duration>[];
    state.debugNetworkDelay = (duration) async {
      delays.add(duration);
    };
    sync.onSync = (project, _) async {
      return ContextSyncStatus(
        phase: ContextSyncPhase.error,
        contextId: project.contextId,
        error: 'fatal: unable to access: Could not resolve host: github.com',
      );
    };

    await state.runContextSyncAllForTest('startup');

    expect(sync.ids, ['p1', 'p1', 'p1']);
    expect(delays, const [
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ]);
  });

  test('a non-network error does not retry and the queue continues', () async {
    final delays = <Duration>[];
    state.debugNetworkDelay = (duration) async {
      delays.add(duration);
    };
    sync.onSync = (project, _) async {
      if (project.id == projectA.id) {
        return ContextSyncStatus(
          phase: ContextSyncPhase.error,
          contextId: project.contextId,
          error: 'Authentication failed',
        );
      }
      return _ok(project);
    };

    await state.runContextSyncAllForTest('interval');

    expect(sync.ids, ['p1', 'p2']);
    expect(delays, isEmpty);
  });

  test('a sync error pauses the next automatic run until manual', () async {
    sync.onSync = (project, _) async {
      return ContextSyncStatus(
        phase: ContextSyncPhase.error,
        contextId: project.contextId,
        error: 'GH001: Large files detected',
      );
    };

    await state.runContextSyncAllForTest('interval');
    expect(sync.ids, ['p1', 'p2']);
    expect(state.autoSyncPausedAfterErrorForTest, isTrue);

    await state.runContextSyncAllForTest('interval');
    await state.runContextSyncForTest(reason: 'project-selected');
    expect(sync.ids, ['p1', 'p2']);

    sync.onSync = (project, _) async => _ok(project);
    await state.runContextSyncForTest(reason: 'manual', force: true);
    expect(sync.ids, ['p1', 'p2', 'p1']);
    expect(state.autoSyncPausedAfterErrorForTest, isFalse);
  });

  test('initialize queues a startup sync of every loaded project', () async {
    final fresh = _stateFor([projectA, projectB], sync);
    fresh.debugPostSyncSuppress = Duration.zero;
    sync.onSync = (project, _) async => _ok(project);
    addTearDown(fresh.dispose);

    await fresh.initialize();
    await fresh.debugContextSyncQueue;

    expect(fresh.selectedProject?.id, projectA.id);
    expect(sync.ids, ['p1', 'p2']);
  });
}

ProjectManagerState _stateFor(List<Project> projects, _RecordingSync sync) {
  return ProjectManagerState(
    storage: _MemoryStorage(projects),
    globalPackageMetadata: _EmptyMetadata(),
    settingsService: _FixedSettings(
      const ContextSyncSettings(
        enabled: true,
        repoUrl: 'https://example.invalid/context.git',
        syncIntervalMinutes: 5,
      ),
    ),
    contextSyncService: sync,
  );
}

Project _project(String id, String contextId, String path) {
  return Project(
    id: id,
    contextId: contextId,
    name: id,
    path: path,
    addedAt: DateTime.utc(2026, 10, 27),
  );
}

ContextSyncStatus _ok(Project project) {
  return ContextSyncStatus(
    phase: ContextSyncPhase.idle,
    contextId: project.contextId,
    lastSyncedAt: DateTime.utc(2026, 10, 27, 6),
    message: 'Already in sync',
  );
}

typedef _SyncHandler = Future<ContextSyncStatus> Function(
  Project project,
  ContextSyncShouldContinue? shouldContinue,
);

class _RecordingSync extends ContextSyncService {
  _SyncHandler? onSync;
  final ids = <String>[];
  var inFlight = 0;
  var maxInFlight = 0;

  @override
  Future<ContextSyncStatus> syncProject({
    required Project project,
    required ContextSyncSettings syncSettings,
    required CursorCliSettings cursorSettings,
    ContextSyncStatusCallback? onStatus,
    ContextSyncShouldContinue? shouldContinue,
  }) async {
    ids.add(project.id);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      final handler = onSync;
      if (handler == null) return _ok(project);
      return await handler(project, shouldContinue);
    } finally {
      inFlight--;
    }
  }
}

class _MemoryStorage extends ProjectStorageService {
  _MemoryStorage(this.projects);

  List<Project> projects;

  @override
  Future<List<Project>> loadProjects() async => List<Project>.of(projects);

  @override
  Future<void> saveProject(Project project) async {
    final index = projects.indexWhere((item) => item.id == project.id);
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.add(project);
    }
  }

  @override
  Future<void> saveProjects(List<Project> next) async {
    projects = List<Project>.of(next);
  }
}

class _EmptyMetadata extends GlobalPackageMetadataService {
  @override
  Future<Map<String, GlobalPackageMetadata>> loadAll() async => {};
}

class _FixedSettings extends SettingsService {
  _FixedSettings(this.sync);

  final ContextSyncSettings sync;

  @override
  Future<ContextSyncSettings> loadContextSyncSettings() async => sync;

  @override
  Future<CursorCliSettings> loadCursorCliSettings() async =>
      const CursorCliSettings();
}
