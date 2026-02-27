import 'dart:typed_data';

import 'color_extractor.dart';
import 'light_estimator.dart';
import 'app_strings.dart';

class PaintingStep {
  final StepKey stepKey;
  final String? lightDir; // translated direction label (passed at render time)
  final String? lightOpp; // opposite direction label

  // Legacy convenience — used only internally; real UI reads via AppStrings
  String get title => stepKey.name;

  PaintingStep({
    required this.stepKey,
    this.lightDir,
    this.lightOpp,
  });
}

class GuideResult {
  final List<ColorCluster> colors;
  final LightDirection lightDirection;
  final List<PaintingStep> steps;
  final int estimatedTimeMinutes;
  final List<Uint8List> stepImages;           // Snapshot mode
  final List<Uint8List> cumulativeStepImages; // Cumulative (layered) mode

  GuideResult({
    required this.colors,
    required this.lightDirection,
    required this.steps,
    required this.estimatedTimeMinutes,
    required this.stepImages,
    required this.cumulativeStepImages,
  });
}

class GuideGenerator {
  static GuideResult generate(List<ColorCluster> colors, LightDirection light, {int maxColors = 6}) {
    List<PaintingStep> steps = [];

    // Assign roles heuristics
    if (colors.isNotEmpty) colors[0].role = 'background';
    if (colors.length > 1) colors[1].role = 'subject';
    if (colors.length > 2) colors[2].role = 'shadow';
    if (colors.length > 3) colors[3].role = 'highlight';
    
    // Dynamic roles for complex palettes (k > 4)
    for (int i = 4; i < colors.length; i++) {
        if (i == colors.length - 1) {
            colors[i].role = 'detail';
        } else {
            colors[i].role = 'structure $i';
        }
    }

    // Limit to baseK/slider selection
    final finalColors = colors.take(maxColors).toList();

    // Precompute direction labels used in step descriptions
    final lightDirEs = LightEstimator.directionToString(light);
    final lightOppEs = _getOppositeDirectionEs(light);

    // 1. Background
    if (finalColors.isNotEmpty) {
      steps.add(PaintingStep(stepKey: StepKey.background));
    }

    // 2. Main mass
    if (finalColors.length > 1) {
      steps.add(PaintingStep(stepKey: StepKey.mainMass));
    }

    // 3. Shadows
    if (finalColors.length > 2) {
      steps.add(PaintingStep(
        stepKey: StepKey.shadows,
        lightOpp: lightOppEs,
      ));
    }

    // 4. Lights
    if (finalColors.length > 3) {
      steps.add(PaintingStep(
        stepKey: StepKey.lights,
        lightDir: lightDirEs,
      ));
    }

    // Dynamic Steps for structure layers
    for (int i = 4; i < finalColors.length - 1; i++) {
      steps.add(PaintingStep(stepKey: StepKey.structure));
    }

    // Final Detail Step
    if (finalColors.length > 4) {
      steps.add(PaintingStep(stepKey: StepKey.details));
    }

    return GuideResult(
      colors: finalColors,
      lightDirection: light,
      steps: steps,
      estimatedTimeMinutes: finalColors.length * 10,
      stepImages: [],
      cumulativeStepImages: [],
    );
  }

  static String _getOppositeDirectionEs(LightDirection dir) {
    switch (dir) {
      case LightDirection.topLeft:    return 'inferior derecha';
      case LightDirection.topRight:   return 'inferior izquierda';
      case LightDirection.bottomLeft: return 'superior derecha';
      case LightDirection.bottomRight:return 'superior izquierda';
      case LightDirection.undefined:  return 'opuesto a la luz principal';
    }
  }
}
