import 'dart:typed_data';

class ColorExtractionResult {
  final List<ColorCluster> dominantColors;
  final List<int> pixelAssignments;
  final int width;
  final int height;

  ColorExtractionResult({
    required this.dominantColors,
    required this.pixelAssignments,
    required this.width,
    required this.height,
  });
}

enum StepKey { background, mainMass, shadows, lights, structure, details }

enum LightDirection {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  undefined
}

class ColorCluster {
  final int r;
  final int g;
  final int b;
  final double percentage;
  String? role;

  ColorCluster({
    required this.r,
    required this.g,
    required this.b,
    required this.percentage,
    this.role,
  });

  String get hexColor {
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
           '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
           '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  Map<String, dynamic> toJson() => {
    'r': r,
    'g': g,
    'b': b,
    'percentage': percentage,
    'role': role,
    'hex': hexColor,
  };
}

class PaintingStep {
  final StepKey stepKey;
  final String? lightDir;
  final String? lightOpp;

  PaintingStep({
    required this.stepKey,
    this.lightDir,
    this.lightOpp,
  });

  Map<String, dynamic> toJson() => {
    'stepKey': stepKey.name,
    'lightDir': lightDir,
    'lightOpp': lightOpp,
  };
}

class GuideResult {
  final List<ColorCluster> colors;
  final LightDirection lightDirection;
  final List<PaintingStep> steps;
  final int estimatedTimeMinutes;
  final List<Uint8List> stepImages;
  final List<Uint8List> cumulativeStepImages;

  GuideResult({
    required this.colors,
    required this.lightDirection,
    required this.steps,
    required this.estimatedTimeMinutes,
    required this.stepImages,
    required this.cumulativeStepImages,
  });
}
