class ProjectItem {
  final String id;
  String name;
  final String? path; // optional file path
  final String? url; // optional remote url (z. B. von einem Upload)
  final String? storagePath; // optional storage path (Supabase)
  final String type; // 'file' | 'image' | 'color' | 'render' | 'note' | 'other'

  ProjectItem({
    required this.id,
    required this.name,
    required this.type,
    this.path,
    this.url,
    this.storagePath,
  });

  /// For color items the hex value is stored in [url] (or [name] as fallback).
  String? get colorHex {
    if (type != 'color') return null;
    final candidate = url ?? name;
    if (candidate.trim().isEmpty) return null;
    return candidate;
  }

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'file',
        path: json['path']?.toString(),
        url: json['url']?.toString(),
        storagePath: json['storagePath']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'path': path,
        'url': url,
        'storagePath': storagePath,
      };
}

class Project {
  final String id;
  String name;
  String? title;
  final List<ProjectItem> items;

  Project({
    required this.id,
    required this.name,
    this.title,
    required this.items,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return Project(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      title: json['title']?.toString(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => ProjectItem.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
