enum WidgetParamKind {
  positional,
  named,
}

class WidgetConstructorParam {
  const WidgetConstructorParam({
    required this.name,
    required this.kind,
    this.type,
    this.isRequired = false,
    this.defaultValue,
  });

  final String name;
  final String? type;
  final bool isRequired;
  final WidgetParamKind kind;
  final String? defaultValue;

  WidgetConstructorParam copyWith({
    String? name,
    String? type,
    bool? isRequired,
    WidgetParamKind? kind,
    String? defaultValue,
  }) {
    return WidgetConstructorParam(
      name: name ?? this.name,
      type: type ?? this.type,
      isRequired: isRequired ?? this.isRequired,
      kind: kind ?? this.kind,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'isRequired': isRequired,
        'kind': kind.name,
        'defaultValue': defaultValue,
      };

  factory WidgetConstructorParam.fromJson(Map<String, dynamic> json) {
    return WidgetConstructorParam(
      name: json['name'] as String,
      type: json['type'] as String?,
      isRequired: json['isRequired'] as bool? ?? false,
      kind: WidgetParamKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => WidgetParamKind.named,
      ),
      defaultValue: json['defaultValue'] as String?,
    );
  }

  /// Backward compatibility for legacy string-only params stored before structured parsing.
  static WidgetConstructorParam? tryFromLegacyString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '{' || trimmed == '}') return null;

    var name = trimmed.replaceFirst(RegExp(r'^required\s+'), '');
    name = name.replaceFirst(RegExp(r'^this\.'), '');
    name = name.replaceFirst(RegExp(r'^super\.'), '');
    if (name.contains('=')) {
      name = name.split('=').first.trim();
    }
    name = name.split(RegExp(r'[,\s{]')).first;
    if (name.isEmpty || name == '{' || name == '}') return null;

    return WidgetConstructorParam(
      name: name,
      kind: WidgetParamKind.named,
      isRequired: raw.trim().startsWith('required '),
    );
  }
}
