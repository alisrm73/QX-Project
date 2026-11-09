class QxProject {
  const QxProject({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String type;
  final String description;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QxProject.fromJson(Map<String, dynamic> json) => QxProject(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        description: (json['description'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
