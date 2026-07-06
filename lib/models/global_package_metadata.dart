class GlobalPackageMetadata {
  const GlobalPackageMetadata({
    required this.packageName,
    this.customDescription = '',
    this.customNotes = '',
    this.updateRisks = '',
    this.updatedAt,
  });

  final String packageName;
  final String customDescription;
  final String customNotes;
  final String updateRisks;
  final DateTime? updatedAt;

  bool get hasCustomData =>
      customDescription.isNotEmpty ||
      customNotes.isNotEmpty ||
      updateRisks.isNotEmpty;

  GlobalPackageMetadata copyWith({
    String? packageName,
    String? customDescription,
    String? customNotes,
    String? updateRisks,
    DateTime? updatedAt,
  }) {
    return GlobalPackageMetadata(
      packageName: packageName ?? this.packageName,
      customDescription: customDescription ?? this.customDescription,
      customNotes: customNotes ?? this.customNotes,
      updateRisks: updateRisks ?? this.updateRisks,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'customDescription': customDescription,
        'customNotes': customNotes,
        'updateRisks': updateRisks,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory GlobalPackageMetadata.fromJson(Map<String, dynamic> json) {
    return GlobalPackageMetadata(
      packageName: json['packageName'] as String,
      customDescription: json['customDescription'] as String? ?? '',
      customNotes: json['customNotes'] as String? ?? '',
      updateRisks: json['updateRisks'] as String? ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
