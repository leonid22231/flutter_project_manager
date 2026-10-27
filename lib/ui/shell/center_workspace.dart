import 'package:flutter/material.dart';
import 'package:project_manager/state/project_manager_state.dart';
import 'package:project_manager/ui/views/empty_state_view.dart';
import 'package:project_manager/ui/views/project_home_view.dart';
import 'package:provider/provider.dart';

class CenterWorkspace extends StatelessWidget {
  const CenterWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectManagerState>().selectedProject;
    if (project == null) {
      return const EmptyStateView();
    }
    return ProjectHomeView(project: project);
  }
}
