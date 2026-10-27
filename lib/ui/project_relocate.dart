import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:project_manager/l10n/app_localizations.dart';
import 'package:project_manager/models/project.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:provider/provider.dart';

Future<void> pickAndRelocateProject(
  BuildContext context,
  Project project,
) async {
  final l10n = context.l10n;
  final path = await FilePicker.platform.getDirectoryPath(
    dialogTitle: l10n.chooseProjectFolder,
  );
  if (path == null || !context.mounted) return;

  final ok = await context.read<ProjectManagerState>().relocateProjectDirectory(
        project.id,
        path,
      );
  if (!context.mounted || ok) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.projectFolderMissing)),
  );
}
