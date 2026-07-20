import 'package:flutter/material.dart';
import 'package:project_manager/core/layout/panel_layout_defaults.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/cursor_cli_bar_status.dart';
import 'package:project_manager/models/cursor_cli_check_result.dart';
import 'package:project_manager/models/gitlab_check_result.dart';
import 'package:project_manager/models/gitlab_settings.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/services/context_sync_git_service.dart';
import 'package:project_manager/services/cursor_cli_service.dart';
import 'package:project_manager/services/gitlab_api_service.dart';
import 'package:project_manager/services/settings_service.dart';

class AppSettingsState extends ChangeNotifier {
  AppSettingsState({
    SettingsService? settings,
    CursorCliService? cursorCli,
    GitLabApiService? gitLabApi,
    ContextSyncGitService? contextSyncGit,
  })  : _settings = settings ?? SettingsService(),
        _cursorCli = cursorCli ?? CursorCliService(),
        _gitLabApi = gitLabApi ?? GitLabApiService(),
        _contextSyncGit = contextSyncGit ?? ContextSyncGitService();

  final SettingsService _settings;
  final CursorCliService _cursorCli;
  final GitLabApiService _gitLabApi;
  final ContextSyncGitService _contextSyncGit;

  Locale _locale = AppLocalizations.fallbackLocale;
  bool _isLoading = true;
  CursorCliSettings _cursorCliSettings = const CursorCliSettings();
  GitLabSettings _gitlabSettings = const GitLabSettings();
  ContextSyncSettings _contextSyncSettings = const ContextSyncSettings();
  CursorCliCheckResult? _lastCursorCliCheck;
  GitLabCheckResult? _lastGitLabCheck;
  ContextSyncGitResult? _lastContextSyncCheck;
  bool _isCheckingCursorCli = false;
  bool _isCheckingGitLab = false;
  bool _isCheckingContextSync = false;

  Locale get locale => _locale;
  bool get isLoading => _isLoading;
  double _leftPanelWidth = PanelLayoutDefaults.leftPanelWidth;
  double _rightPanelWidth = PanelLayoutDefaults.rightPanelWidth;
  double _docSidebarWidth = PanelLayoutDefaults.docSidebarWidth;
  double _projectsPaneHeight = PanelLayoutDefaults.projectsPaneHeight;
  double _uiScale = SettingsService.defaultUiScale;

  double get leftPanelWidth => _leftPanelWidth;
  double get rightPanelWidth => _rightPanelWidth;
  double get docSidebarWidth => _docSidebarWidth;
  double get projectsPaneHeight => _projectsPaneHeight;
  double get uiScale => _uiScale;
  CursorCliSettings get cursorCliSettings => _cursorCliSettings;
  GitLabSettings get gitlabSettings => _gitlabSettings;
  ContextSyncSettings get contextSyncSettings => _contextSyncSettings;
  CursorCliCheckResult? get lastCursorCliCheck => _lastCursorCliCheck;
  GitLabCheckResult? get lastGitLabCheck => _lastGitLabCheck;
  ContextSyncGitResult? get lastContextSyncCheck => _lastContextSyncCheck;
  bool get isCheckingCursorCli => _isCheckingCursorCli;
  bool get isCheckingGitLab => _isCheckingGitLab;
  bool get isCheckingContextSync => _isCheckingContextSync;
  CursorCliService get cursorCliService => _cursorCli;
  GitLabApiService get gitLabApiService => _gitLabApi;

  CursorCliBarStatus get cursorCliBarStatus => resolveCursorCliBarStatus(
        enabled: _cursorCliSettings.enabled,
        isChecking: _isCheckingCursorCli,
        defaultModel: _cursorCliSettings.defaultModel,
        lastCheck: _lastCursorCliCheck,
      );

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _locale = await _settings.loadLocale();
      _leftPanelWidth = await _settings.loadLeftPanelWidth();
      _rightPanelWidth = await _settings.loadRightPanelWidth();
      _docSidebarWidth = await _settings.loadDocSidebarWidth();
      _projectsPaneHeight = await _settings.loadProjectsPaneHeight();
      _uiScale = await _settings.loadUiScale();
      _cursorCliSettings = await _settings.loadCursorCliSettings();
      _gitlabSettings = await _settings.loadGitLabSettings();
      _contextSyncSettings = await _settings.loadContextSyncSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    if (_cursorCliSettings.enabled) {
      await checkCursorCliConnection();
    }
    if (_gitlabSettings.enabled) {
      await checkGitLabConnection();
    }
  }

  Future<void> setUiScale(double scale) async {
    final clamped = scale.clamp(
      SettingsService.minUiScale,
      SettingsService.maxUiScale,
    );
    if (_uiScale == clamped) return;
    _uiScale = clamped;
    notifyListeners();
    await _settings.saveUiScale(clamped);
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    await _settings.saveLocale(locale);
  }

  Future<void> saveCursorCliSettings(CursorCliSettings settings) async {
    _cursorCliSettings = settings;
    notifyListeners();
    await _settings.saveCursorCliSettings(settings);
    if (settings.enabled) {
      await checkCursorCliConnection(settings);
    } else {
      _lastCursorCliCheck = null;
      notifyListeners();
    }
  }

  Future<CursorCliCheckResult> checkCursorCliConnection([
    CursorCliSettings? settings,
  ]) async {
    final target = settings ?? _cursorCliSettings;
    _isCheckingCursorCli = true;
    notifyListeners();

    try {
      final result = await _cursorCli.checkConnection(target);
      _lastCursorCliCheck = result;
      return result;
    } finally {
      _isCheckingCursorCli = false;
      notifyListeners();
    }
  }

  Future<void> saveGitLabSettings(GitLabSettings settings) async {
    _gitlabSettings = settings;
    notifyListeners();
    await _settings.saveGitLabSettings(settings);
    if (settings.enabled) {
      await checkGitLabConnection(settings);
    } else {
      _lastGitLabCheck = null;
      notifyListeners();
    }
  }

  Future<GitLabCheckResult> checkGitLabConnection([
    GitLabSettings? settings,
  ]) async {
    final target = settings ?? _gitlabSettings;
    _isCheckingGitLab = true;
    notifyListeners();

    try {
      final result = await _gitLabApi.checkConnection(target);
      _lastGitLabCheck = result;
      return result;
    } finally {
      _isCheckingGitLab = false;
      notifyListeners();
    }
  }

  Future<void> saveContextSyncSettings(ContextSyncSettings settings) async {
    _contextSyncSettings = settings;
    notifyListeners();
    await _settings.saveContextSyncSettings(settings);
  }

  Future<ContextSyncGitResult> checkContextSyncRepo([
    ContextSyncSettings? settings,
  ]) async {
    final target = settings ?? _contextSyncSettings;
    _isCheckingContextSync = true;
    notifyListeners();

    try {
      final result = await _contextSyncGit.testRemote(target.repoUrl);
      _lastContextSyncCheck = result;
      return result;
    } finally {
      _isCheckingContextSync = false;
      notifyListeners();
    }
  }

  void setLeftPanelWidth(double width) {
    final clamped = width.clamp(
      PanelLayoutDefaults.minSidePanelWidth,
      PanelLayoutDefaults.maxSidePanelWidth,
    );
    if (_leftPanelWidth == clamped) return;
    _leftPanelWidth = clamped;
    notifyListeners();
    _settings.saveLeftPanelWidth(clamped);
  }

  void setRightPanelWidth(double width) {
    final clamped = width.clamp(
      PanelLayoutDefaults.minSidePanelWidth,
      PanelLayoutDefaults.maxSidePanelWidth,
    );
    if (_rightPanelWidth == clamped) return;
    _rightPanelWidth = clamped;
    notifyListeners();
    _settings.saveRightPanelWidth(clamped);
  }

  void setDocSidebarWidth(double width) {
    final clamped = width.clamp(
      PanelLayoutDefaults.minDocSidebarWidth,
      PanelLayoutDefaults.maxDocSidebarWidth,
    );
    if (_docSidebarWidth == clamped) return;
    _docSidebarWidth = clamped;
    notifyListeners();
    _settings.saveDocSidebarWidth(clamped);
  }

  void setProjectsPaneHeight(double height) {
    final clamped = height.clamp(
      PanelLayoutDefaults.minProjectsPaneHeight,
      PanelLayoutDefaults.maxProjectsPaneHeight,
    );
    if (_projectsPaneHeight == clamped) return;
    _projectsPaneHeight = clamped;
    notifyListeners();
    _settings.saveProjectsPaneHeight(clamped);
  }
}
