class WorkspaceTask {
  const WorkspaceTask({
    required this.id,
    required this.title,
    required this.notes,
    required this.isCompleted,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String notes;
  final bool isCompleted;
  final DateTime createdAt;

  WorkspaceTask copyWith({bool? isCompleted}) => WorkspaceTask(
        id: id,
        title: title,
        notes: notes,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkspaceTask.fromJson(Map<String, dynamic> json) => WorkspaceTask(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: (json['notes'] as String?) ?? '',
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
