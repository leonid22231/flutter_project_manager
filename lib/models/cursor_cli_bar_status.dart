import 'package:project_manager/models/cursor_cli_check_result.dart';

enum CursorCliBarStatus {
  disabled,
  checking,
  connected,
  unavailable,
  noModel,
}

CursorCliBarStatus resolveCursorCliBarStatus({
  required bool enabled,
  required bool isChecking,
  required String defaultModel,
  CursorCliCheckResult? lastCheck,
}) {
  if (!enabled) return CursorCliBarStatus.disabled;
  if (isChecking) return CursorCliBarStatus.checking;
  if (lastCheck == null) return CursorCliBarStatus.unavailable;

  if (!lastCheck.cliAvailable || lastCheck.authenticated != true) {
    return CursorCliBarStatus.unavailable;
  }

  final model = defaultModel.trim();
  if (model.isEmpty) return CursorCliBarStatus.noModel;

  if (lastCheck.availableModels.isNotEmpty &&
      !lastCheck.availableModels.contains(model)) {
    return CursorCliBarStatus.noModel;
  }

  return CursorCliBarStatus.connected;
}
