enum ProjectStatus {
  active('Active'),
  paused('Paused'),
  archived('Archived'),
  draft('Draft');

  const ProjectStatus(this.label);
  final String label;

  static ProjectStatus fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ProjectStatus.active,
    );
  }
}
