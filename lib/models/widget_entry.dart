import 'package:project_manager/models/widget_constructor_param.dart';
import 'package:project_manager/models/widget_origin.dart';
import 'package:project_manager/models/widget_usage_entry.dart';

class WidgetEntry {
  const WidgetEntry({
    required this.id,
    required this.name,
    required this.filePath,
    required this.type,
    required this.origin,
    this.description,
    this.constructorParams = const [],
    this.notes,
    this.definitionLine,
    this.superType,
    this.stateClassName,
    this.usages = const [],
    this.isConstConstructor = false,
    this.enrichedByCursor = false,
  });

  final String id;
  final String name;
  final String filePath;
  final String type;
  final WidgetOrigin origin;
  final String? description;
  final List<WidgetConstructorParam> constructorParams;
  final String? notes;
  final int? definitionLine;
  final String? superType;
  final String? stateClassName;
  final List<WidgetUsageEntry> usages;
  final bool isConstConstructor;
  final bool enrichedByCursor;

  bool get isDefinedInProject => filePath.isNotEmpty && definitionLine != null;

  int get usageCount => usages.length;

  WidgetEntry copyWith({
    String? id,
    String? name,
    String? filePath,
    String? type,
    WidgetOrigin? origin,
    String? description,
    List<WidgetConstructorParam>? constructorParams,
    String? notes,
    int? definitionLine,
    String? superType,
    String? stateClassName,
    List<WidgetUsageEntry>? usages,
    bool? isConstConstructor,
    bool? enrichedByCursor,
  }) {
    return WidgetEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      origin: origin ?? this.origin,
      description: description ?? this.description,
      constructorParams: constructorParams ?? this.constructorParams,
      notes: notes ?? this.notes,
      definitionLine: definitionLine ?? this.definitionLine,
      superType: superType ?? this.superType,
      stateClassName: stateClassName ?? this.stateClassName,
      usages: usages ?? this.usages,
      isConstConstructor: isConstConstructor ?? this.isConstConstructor,
      enrichedByCursor: enrichedByCursor ?? this.enrichedByCursor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'type': type,
        'origin': origin.name,
        'description': description,
        'constructorParams': constructorParams.map((p) => p.toJson()).toList(),
        'notes': notes,
        'definitionLine': definitionLine,
        'superType': superType,
        'stateClassName': stateClassName,
        'usages': usages.map((u) => u.toJson()).toList(),
        'isConstConstructor': isConstConstructor,
        'enrichedByCursor': enrichedByCursor,
      };

  factory WidgetEntry.fromJson(Map<String, dynamic> json) {
    return WidgetEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      filePath: json['filePath'] as String? ?? '',
      type: json['type'] as String? ?? 'Widget',
      origin: WidgetOrigin.fromString(json['origin'] as String? ?? 'custom'),
      description: json['description'] as String?,
      constructorParams: _parseConstructorParams(json['constructorParams']),
      notes: json['notes'] as String?,
      definitionLine: json['definitionLine'] as int?,
      superType: json['superType'] as String?,
      stateClassName: json['stateClassName'] as String?,
      usages: (json['usages'] as List<dynamic>?)
              ?.map((e) => WidgetUsageEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isConstConstructor: json['isConstConstructor'] as bool? ?? false,
      enrichedByCursor: json['enrichedByCursor'] as bool? ?? false,
    );
  }

  static List<WidgetConstructorParam> _parseConstructorParams(dynamic raw) {
    if (raw is! List<dynamic>) return const [];
    final result = <WidgetConstructorParam>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final param = WidgetConstructorParam.fromJson(entry);
        if (_isValidParamName(param.name)) result.add(param);
      } else {
        final legacy = WidgetConstructorParam.tryFromLegacyString(entry.toString());
        if (legacy != null) result.add(legacy);
      }
    }
    return result;
  }

  static bool _isValidParamName(String name) =>
      name.isNotEmpty && name != '{' && name != '}';
}

extension WidgetEntryListX on Iterable<WidgetEntry> {
  List<WidgetEntry> forRelativeFile(String relativePath) {
    final normalized = relativePath.replaceAll(r'\', '/');
    return where(
      (widget) =>
          widget.filePath.replaceAll(r'\', '/') == normalized ||
          widget.usages.any(
            (usage) => usage.filePath.replaceAll(r'\', '/') == normalized,
          ),
    ).toList();
  }

  List<WidgetEntry> definedInFile(String relativePath) {
    final normalized = relativePath.replaceAll(r'\', '/');
    return where(
      (widget) => widget.filePath.replaceAll(r'\', '/') == normalized,
    ).toList();
  }
}
