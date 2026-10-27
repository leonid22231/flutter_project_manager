import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:project_manager/core/layout/panel_layout_defaults.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/context_sync_settings.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/gitlab_settings.dart';
import 'package:project_manager/models/windows_launch_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _languageKey = 'settings_language';
  static const _cursorCliSettingsKey = 'settings_cursor_cli';
  static const _gitlabSettingsKey = 'settings_gitlab';
  static const _contextSyncSettingsKey = 'settings_context_sync';
  static const _windowsLaunchSettingsKey = 'settings_windows_launch';
  static const _leftPanelWidthKey = 'layout_left_panel_width';
  static const _rightPanelWidthKey = 'layout_right_panel_width';
  static const _docSidebarWidthKey = 'layout_doc_sidebar_width';
  static const _projectsPaneHeightKey = 'layout_projects_pane_height';
  static const _uiScaleKey = 'settings_ui_scale';

  static const defaultUiScale = 1.0;
  static const minUiScale = 0.70;
  static const maxUiScale = 1.25;

  Future<Locale> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageKey);
    if (code == null || code.isEmpty) {
      return AppLocalizations.fallbackLocale;
    }
    return Locale(code);
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
  }

  Future<double?> loadDouble(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key);
  }

  Future<void> saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<double> loadLeftPanelWidth() async =>
      (await loadDouble(_leftPanelWidthKey)) ??
      PanelLayoutDefaults.leftPanelWidth;

  Future<double> loadRightPanelWidth() async =>
      (await loadDouble(_rightPanelWidthKey)) ??
      PanelLayoutDefaults.rightPanelWidth;

  Future<double> loadDocSidebarWidth() async =>
      (await loadDouble(_docSidebarWidthKey)) ??
      PanelLayoutDefaults.docSidebarWidth;

  Future<double> loadProjectsPaneHeight() async =>
      (await loadDouble(_projectsPaneHeightKey)) ??
      PanelLayoutDefaults.projectsPaneHeight;

  Future<void> saveLeftPanelWidth(double value) =>
      saveDouble(_leftPanelWidthKey, value);

  Future<void> saveRightPanelWidth(double value) =>
      saveDouble(_rightPanelWidthKey, value);

  Future<void> saveDocSidebarWidth(double value) =>
      saveDouble(_docSidebarWidthKey, value);

  Future<void> saveProjectsPaneHeight(double value) =>
      saveDouble(_projectsPaneHeightKey, value);

  Future<double> loadUiScale() async {
    final value = await loadDouble(_uiScaleKey);
    if (value == null) return defaultUiScale;
    return value.clamp(minUiScale, maxUiScale);
  }

  Future<void> saveUiScale(double value) =>
      saveDouble(_uiScaleKey, value.clamp(minUiScale, maxUiScale));

  Future<CursorCliSettings> loadCursorCliSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cursorCliSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const CursorCliSettings();
    }

    try {
      return CursorCliSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const CursorCliSettings();
    }
  }

  Future<void> saveCursorCliSettings(CursorCliSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cursorCliSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<GitLabSettings> loadGitLabSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gitlabSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const GitLabSettings();
    }

    try {
      return GitLabSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const GitLabSettings();
    }
  }

  Future<void> saveGitLabSettings(GitLabSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gitlabSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<ContextSyncSettings> loadContextSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contextSyncSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const ContextSyncSettings();
    }

    try {
      return ContextSyncSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ContextSyncSettings();
    }
  }

  Future<void> saveContextSyncSettings(ContextSyncSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contextSyncSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  Future<WindowsLaunchSettings> loadWindowsLaunchSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_windowsLaunchSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const WindowsLaunchSettings();
    }

    try {
      return WindowsLaunchSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const WindowsLaunchSettings();
    }
  }

  Future<void> saveWindowsLaunchSettings(WindowsLaunchSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _windowsLaunchSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
