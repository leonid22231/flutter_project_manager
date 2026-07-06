class ChangeRecord {
  const ChangeRecord({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.description,
    this.category,
  });

  final String id;
  final DateTime timestamp;
  final String title;
  final String description;
  final String? category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'title': title,
        'description': description,
        'category': category,
      };

  factory ChangeRecord.fromJson(Map<String, dynamic> json) {
    return ChangeRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String?,
    );
  }
}
