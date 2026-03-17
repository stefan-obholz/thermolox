import 'package:flutter_test/flutter_test.dart';

import 'package:thermolox/models/project_measurement.dart';
import 'package:thermolox/utils/measurement_calculator.dart';

ProjectMeasurement _make({
  double? length,
  double? width,
  double? height,
  List<RoomOpening> openings = const [],
}) {
  return ProjectMeasurement(
    id: 'test',
    projectId: 'p1',
    userId: 'u1',
    method: 'manual',
    lengthM: length,
    widthM: width,
    heightM: height,
    openings: openings,
    confidence: null,
    createdAt: null,
    updatedAt: null,
  );
}

void main() {
  group('MeasurementCalculator', () {
    test('basic room without openings', () {
      final m = _make(length: 5, width: 4, height: 2.5);
      final r = MeasurementCalculator.calculate(m);

      expect(r.wallAreaM2, 45.0); // 2*(5+4)*2.5
      expect(r.openingAreaM2, 0.0);
      expect(r.netWallAreaM2, 45.0);
      expect(r.recommendedWallAreaM2, closeTo(49.5, 0.01)); // +10%
      expect(r.paintLiters, greaterThan(0));
      expect(r.paintBuckets, greaterThan(0));
      expect(r.thermoSealM, 0.0);
      expect(r.thermoSealPacks, 0);
    });

    test('room with window and door', () {
      final m = _make(
        length: 5,
        width: 4,
        height: 2.5,
        openings: [
          const RoomOpening(type: 'window', widthM: 1.2, heightM: 1.0),
          const RoomOpening(type: 'door', widthM: 0.9, heightM: 2.1),
        ],
      );
      final r = MeasurementCalculator.calculate(m);

      final expectedOpeningArea = 1.2 * 1.0 + 0.9 * 2.1;
      expect(r.openingAreaM2, closeTo(expectedOpeningArea, 0.01));
      expect(r.netWallAreaM2, closeTo(45.0 - expectedOpeningArea, 0.01));
      expect(r.thermoSealM, greaterThan(0));
      expect(r.thermoSealPacks, greaterThan(0));
    });

    test('opening with count > 1', () {
      final m = _make(
        length: 5,
        width: 4,
        height: 2.5,
        openings: [
          const RoomOpening(
              type: 'window', widthM: 1.0, heightM: 1.0, count: 3),
        ],
      );
      final r = MeasurementCalculator.calculate(m);

      expect(r.openingAreaM2, 3.0); // 1*1*3
    });

    test('null dimensions yield zero', () {
      final m = _make();
      final r = MeasurementCalculator.calculate(m);

      expect(r.wallAreaM2, 0.0);
      expect(r.netWallAreaM2, 0.0);
      expect(r.paintLiters, 0.0);
      expect(r.paintBuckets, 0);
    });

    test('opening area cannot exceed wall area (clamped)', () {
      final m = _make(
        length: 2,
        width: 2,
        height: 2.5,
        openings: [
          const RoomOpening(
              type: 'window', widthM: 10, heightM: 10, count: 5),
        ],
      );
      final r = MeasurementCalculator.calculate(m);

      expect(r.netWallAreaM2, 0.0);
    });

    test('paint buckets round up', () {
      final m = _make(length: 3, width: 3, height: 2.5);
      final r = MeasurementCalculator.calculate(m);

      expect(r.paintBuckets, greaterThanOrEqualTo(1));
      // Buckets must be whole numbers
      expect(r.paintBuckets, equals(r.paintBuckets.round()));
    });
  });

  group('RoomOpening', () {
    test('area calculation', () {
      const o = RoomOpening(type: 'door', widthM: 0.9, heightM: 2.1);
      expect(o.area, closeTo(1.89, 0.01));
    });

    test('perimeter calculation', () {
      const o = RoomOpening(type: 'window', widthM: 1.2, heightM: 1.0);
      expect(o.perimeter, closeTo(4.4, 0.01));
    });

    test('fromJson with snake_case', () {
      final o = RoomOpening.fromJson({
        'type': 'door',
        'width_m': 0.9,
        'height_m': 2.1,
        'count': 2,
      });
      expect(o.type, 'door');
      expect(o.widthM, 0.9);
      expect(o.heightM, 2.1);
      expect(o.count, 2);
      expect(o.area, closeTo(3.78, 0.01));
    });

    test('fromJson with camelCase fallback', () {
      final o = RoomOpening.fromJson({
        'type': 'window',
        'widthM': 1.5,
        'heightM': 1.2,
      });
      expect(o.widthM, 1.5);
      expect(o.heightM, 1.2);
    });

    test('fromJson missing values default to zero', () {
      final o = RoomOpening.fromJson({'type': 'opening'});
      expect(o.widthM, 0.0);
      expect(o.heightM, 0.0);
      expect(o.count, 1);
    });

    test('toJson roundtrip', () {
      const o = RoomOpening(
          type: 'window', widthM: 1.2, heightM: 1.0, count: 2);
      final json = o.toJson();
      final restored = RoomOpening.fromJson(json);
      expect(restored.type, o.type);
      expect(restored.widthM, o.widthM);
      expect(restored.heightM, o.heightM);
      expect(restored.count, o.count);
    });
  });

  group('ProjectMeasurement', () {
    test('fromJson parses all fields', () {
      final m = ProjectMeasurement.fromJson({
        'id': 'abc',
        'project_id': 'p1',
        'user_id': 'u1',
        'method': 'lidar_roomplan',
        'length_m': 5.0,
        'width_m': 4.0,
        'height_m': 2.5,
        'confidence': 0.85,
        'openings': [
          {'type': 'door', 'width_m': 0.9, 'height_m': 2.1, 'count': 1},
        ],
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(m.id, 'abc');
      expect(m.method, 'lidar_roomplan');
      expect(m.lengthM, 5.0);
      expect(m.openings.length, 1);
      expect(m.confidence, 0.85);
      expect(m.createdAt, isNotNull);
    });

    test('fromJson handles missing openings', () {
      final m = ProjectMeasurement.fromJson({
        'id': 'x',
        'project_id': 'p',
        'user_id': 'u',
        'method': 'manual',
      });
      expect(m.openings, isEmpty);
      expect(m.lengthM, isNull);
    });

    test('empty factory', () {
      final m = ProjectMeasurement.empty(
        projectId: 'p1',
        userId: 'u1',
      );
      expect(m.id, '');
      expect(m.method, 'manual');
      expect(m.lengthM, isNull);
      expect(m.openings, isEmpty);
    });

    test('toInsertJson includes all fields', () {
      final m = _make(
        length: 5,
        width: 4,
        height: 2.5,
      );
      final json = m.toInsertJson(userId: 'u1');
      expect(json['project_id'], 'p1');
      expect(json['user_id'], 'u1');
      expect(json['length_m'], 5.0);
      expect(json['updated_at'], isNotNull);
    });
  });
}
