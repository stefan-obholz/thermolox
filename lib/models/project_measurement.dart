class RoomOpening {
  final String type;
  final double widthM;
  final double heightM;
  final int count;

  const RoomOpening({
    required this.type,
    required this.widthM,
    required this.heightM,
    this.count = 1,
  });

  double get area => widthM * heightM * count;
  double get perimeter => 2 * (widthM + heightM) * count;

  factory RoomOpening.fromJson(Map<String, dynamic> json) {
    return RoomOpening(
      type: json['type']?.toString() ?? 'opening',
      widthM: (json['width_m'] as num?)?.toDouble() ??
          (json['widthM'] as num?)?.toDouble() ??
          0.0,
      heightM: (json['height_m'] as num?)?.toDouble() ??
          (json['heightM'] as num?)?.toDouble() ??
          0.0,
      count: (json['count'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'width_m': widthM,
        'height_m': heightM,
        'count': count,
      };
}

class ProjectMeasurement {
  final String id;
  final String projectId;
  final String userId;
  final String method;
  final double? lengthM;
  final double? widthM;
  final double? heightM;
  final List<RoomOpening> openings;
  final double? confidence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProjectMeasurement({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.method,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    required this.openings,
    required this.confidence,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectMeasurement.empty({
    required String projectId,
    required String userId,
    String method = 'manual',
  }) {
    return ProjectMeasurement(
      id: '',
      projectId: projectId,
      userId: userId,
      method: method,
      lengthM: null,
      widthM: null,
      heightM: null,
      openings: const [],
      confidence: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory ProjectMeasurement.fromJson(Map<String, dynamic> json) {
    final rawOpenings = json['openings'];
    final openings = <RoomOpening>[];
    if (rawOpenings is List) {
      for (final entry in rawOpenings) {
        if (entry is Map<String, dynamic>) {
          openings.add(RoomOpening.fromJson(entry));
        } else if (entry is Map) {
          openings.add(RoomOpening.fromJson(entry.cast<String, dynamic>()));
        }
      }
    }
    return ProjectMeasurement(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      method: json['method']?.toString() ?? 'manual',
      lengthM: (json['length_m'] as num?)?.toDouble(),
      widthM: (json['width_m'] as num?)?.toDouble(),
      heightM: (json['height_m'] as num?)?.toDouble(),
      openings: openings,
      confidence: (json['confidence'] as num?)?.toDouble(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toInsertJson({
    required String userId,
  }) {
    return {
      'project_id': projectId,
      'user_id': userId,
      'method': method,
      'length_m': lengthM,
      'width_m': widthM,
      'height_m': heightM,
      'openings': openings.map((o) => o.toJson()).toList(),
      'confidence': confidence,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
