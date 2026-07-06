class DocumentationLink {
  const DocumentationLink({
    required this.id,
    required this.title,
    required this.url,
    this.description,
  });

  final String id;
  final String title;
  final String url;
  final String? description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'description': description,
      };

  factory DocumentationLink.fromJson(Map<String, dynamic> json) {
    return DocumentationLink(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      description: json['description'] as String?,
    );
  }
}
