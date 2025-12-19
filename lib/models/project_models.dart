class ProjectItem {
  final String id;
  String name;
  final String? path; // optional file path
  final String? url; // optional remote url (z. B. von einem Upload)
  final String type; // 'file' | 'image' | 'other'

  ProjectItem({
    required this.id,
    required this.name,
    required this.type,
    this.path,
    this.url,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'file',
        path: json['path'] as String?,
        url: json['url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'path': path,
        'url': url,
      };
}

class Project {
  final String id;
  String name;
  final List<ProjectItem> items;

  Project({
    required this.id,
    required this.name,
    required this.items,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return Project(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      items: rawItems
          .map((e) => ProjectItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
