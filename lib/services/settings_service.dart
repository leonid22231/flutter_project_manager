import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:project_manager/core/layout/panel_layout_defaults.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/cursor_cli_settings.dart';
import 'package:project_manager/models/gitlab_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _languageKey = 'settings_language';
  static const _cursorCliSettingsKey = 'settings_cursor_cli';
  static const _gitlabSettingsKey = 'settings_gitlab';
  static const _leftPanelWidthKey = 'layout_left_panel_width';
  static const _rightPanelWidthKey = 'layout_right_panel_width';
  static const _docSidebarWidthKey = 'layout_doc_sidebar_width';
  static const _projectsPaneHeightKey = 'layout_projects_pane_height';

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
}
