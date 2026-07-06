enum DependencySourceType {
  pub('pub'),
  git('git'),
  path('path'),
  sdk('sdk');

  const DependencySourceType(this.label);
  final String label;

  static DependencySourceType fromString(String value) {
    return DependencySourceType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => DependencySourceType.pub,
    );
  }
}
