enum WidgetOrigin {
  custom('Custom'),
  library('Library');

  const WidgetOrigin(this.label);
  final String label;

  static WidgetOrigin fromString(String value) {
    return WidgetOrigin.values.firstWhere(
      (o) => o.name == value,
      orElse: () => WidgetOrigin.custom,
    );
  }
}
