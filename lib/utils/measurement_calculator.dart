import '../models/project_measurement.dart';

class MeasurementResult {
  final double wallAreaM2;
  final double openingAreaM2;
  final double netWallAreaM2;
  final double recommendedWallAreaM2;
  final double paintLiters;
  final int paintBuckets;
  final double thermoSealM;
  final int thermoSealPacks;

  const MeasurementResult({
    required this.wallAreaM2,
    required this.openingAreaM2,
    required this.netWallAreaM2,
    required this.recommendedWallAreaM2,
    required this.paintLiters,
    required this.paintBuckets,
    required this.thermoSealM,
    required this.thermoSealPacks,
  });
}

class MeasurementCalculator {
  static const double coverageM2PerLiter = 18.0;
  static const double litersPerCoverageArea = 4.5;
  static const double bucketLiters = 4.5;
  static const double wasteFactor = 0.10;
  static const int coats = 2;
  static const double thermoSealPackM = 6.0;

  static MeasurementResult calculate(ProjectMeasurement measurement) {
    final length = measurement.lengthM ?? 0.0;
    final width = measurement.widthM ?? 0.0;
    final height = measurement.heightM ?? 0.0;
    final wallArea = 2 * (length + width) * height;
    var openingArea = 0.0;
    var thermoSeal = 0.0;
    for (final opening in measurement.openings) {
      openingArea += opening.area;
      thermoSeal += opening.perimeter;
    }

    final netWallArea = (wallArea - openingArea).clamp(0.0, double.infinity);
    final recommendedArea = netWallArea * (1 + wasteFactor);
    final litersPerM2 = litersPerCoverageArea / coverageM2PerLiter;
    final liters = recommendedArea * litersPerM2 * coats;
    final buckets = liters.isFinite ? (liters / bucketLiters).ceil() : 0;
    final thermoSealRecommended = thermoSeal * (1 + wasteFactor);
    final thermoSealPacks = thermoSealRecommended.isFinite
        ? (thermoSealRecommended / thermoSealPackM).ceil()
        : 0;

    return MeasurementResult(
      wallAreaM2: wallArea,
      openingAreaM2: openingArea,
      netWallAreaM2: netWallArea,
      recommendedWallAreaM2: recommendedArea,
      paintLiters: liters,
      paintBuckets: buckets,
      thermoSealM: thermoSealRecommended,
      thermoSealPacks: thermoSealPacks,
    );
  }
}
