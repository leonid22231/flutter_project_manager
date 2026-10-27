import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/services/ai_folder_reader.dart';
import 'package:project_manager/services/latest_ai_task.dart';
import 'package:project_manager/services/project_storage_service.dart';
import 'package:project_manager/services/settings_service.dart';
import 'package:project_manager/state/project_manager_state.dart';

void main() {
  test('latest .ai task is the context with the newest updated_at', () {
    final temp = Directory.systemTemp.createTempSync('pm_latest_task_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    _writeTask(
      temp,
      'old',
      title: 'Older',
      updatedAt: '2026-10-01T00:00:00Z',
    );
    _writeTask(
      temp,
      'new',
      title: 'Newer task',
      updatedAt: '2026-10-27T06:00:00Z',
    );
    _writeTask(temp, 'blank', title: '', updatedAt: '2026-10-28T00:00:00Z');

    final task = readLatestAiTask(temp.path);
    expect(task?.title, 'Newer task');
    expect(readLatestAiTask('${temp.path}\\missing'), isNull);
  });

  test('relocate updates the path only when the directory exists', () async {
    final temp = Directory.systemTemp.createTempSync('pm_relocate_');
    final gone = Directory('${temp.path}\\gone');
    final moved = Directory('${temp.path}\\moved')..createSync(recursive: true);
    File('${moved.path}\\pubspec.yaml').writeAsStringSync('name: moved\n');
    final project = Project(
      id: 'p1',
      contextId: '11111111-1111-4111-8111-111111111111',
      name: 'Demo',
      path: gone.path,
      addedAt: DateTime.utc(2026, 10, 27),
    );
    final state = ProjectManagerState(
      storage: _MemoryStorage([project]),
      settingsService: _QuietSettings(),
    );
    addTearDown(() async {
      state.dispose();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });

    state.setProjectsForTest([project], selected: project);
    expect(state.isProjectDirectoryPresent(project), isFalse);

    final rejected = await state.relocateProjectDirectory(
      project.id,
      '${temp.path}\\no-such-dir',
    );
    expect(rejected, isFalse);
    expect(state.projects.single.path, gone.path);

    final accepted = await state.relocateProjectDirectory(project.id, moved.path);
    expect(accepted, isTrue);
    expect(state.projects.single.path, moved.path);
    expect(state.isProjectDirectoryPresent(state.projects.single), isTrue);
    expect(state.selectedProject?.id, project.id);
  });

  test('a folder that only contains .ai is not the project', () {
    final temp = Directory.systemTemp.createTempSync('pm_stub_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    Directory('${temp.path}\\.ai').createSync();
    final project = Project(
      id: 'p1',
      contextId: '11111111-1111-4111-8111-111111111111',
      name: 'Stub',
      path: temp.path,
      addedAt: DateTime.utc(2026, 10, 27),
    );
    final state = ProjectManagerState(
      storage: _MemoryStorage([project]),
      settingsService: _QuietSettings(),
    );
    addTearDown(state.dispose);
    state.setProjectsForTest([project], selected: project);
    expect(state.isProjectDirectoryPresent(project), isFalse);

    File('${temp.path}\\pubspec.yaml').writeAsStringSync('name: real\n');
    expect(state.isProjectDirectoryPresent(project), isTrue);
  });

  test('ai folder reader lists memories and tasks without creating files', () {
    final temp = Directory.systemTemp.createTempSync('pm_ai_read_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final ai = Directory('${temp.path}\\.ai')..createSync();
    File('${ai.path}\\memories.json').writeAsStringSync(
      '[{"summary":"Remember this","date":"2026-10-01","notes":"detail"}]',
    );
    File('${ai.path}\\agent-memory.json').writeAsStringSync(
      '{"entries":[{"id":"m1","content":"Learned fact","createdAt":"2026-10-02T00:00:00Z","tags":[]}]}',
    );
    File('${ai.path}\\agent-profile.json').writeAsStringSync(
      '{"selfAnalysis":"I look at this project."}',
    );
    _writeTask(
      temp,
      'task-a',
      title: 'Task A',
      updatedAt: '2026-10-03T00:00:00Z',
    );

    final snapshot = readAiFolder(temp.path);
    expect(snapshot.memories.single.title, 'Remember this');
    expect(snapshot.memories.single.body, 'detail');
    expect(snapshot.agentMemory.single.title, 'Learned fact');
    expect(snapshot.tasks.single.title, 'Task A');
    expect(snapshot.selfAnalysis, 'I look at this project.');
    Directory('${ai.path}\\index').createSync();
    File('${ai.path}\\index\\open-questions.json').writeAsStringSync(
      '{"questions":[{"question":"Still open?","status":"open","whyNeeded":"because"},{"question":"Already answered","status":"answered"}]}',
    );
    final withQuestions = readAiFolder(temp.path);
    expect(withQuestions.openQuestions.single.title, 'Still open?');
    expect(withQuestions.openQuestions.single.body, 'because');
    expect(File('${temp.path}\\extra').existsSync(), isFalse);
  });
}

void _writeTask(
  Directory root,
  String folder, {
  required String title,
  required String updatedAt,
}) {
  final dir = Directory('${root.path}\\.ai\\$folder')..createSync(recursive: true);
  File('${dir.path}\\context.json').writeAsStringSync(
    '{"title":"$title","updated_at":"$updatedAt"}',
  );
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
}

class _QuietSettings extends SettingsService {
  @override
  Future<ContextSyncSettings> loadContextSyncSettings() async =>
      const ContextSyncSettings();

  @override
  Future<CursorCliSettings> loadCursorCliSettings() async =>
      const CursorCliSettings();
}
