import 'dart:typed_data';

import 'color_extractor.dart';
import 'light_estimator.dart';

class PaintingStep {
  final String title;
  final String description;

  PaintingStep({required this.title, required this.description});
}

class GuideResult {
  final List<ColorCluster> colors;
  final LightDirection lightDirection;
  final List<PaintingStep> steps;
  final int estimatedTimeMinutes;
  final List<Uint8List> stepImages;

  GuideResult({
    required this.colors,
    required this.lightDirection,
    required this.steps,
    required this.estimatedTimeMinutes,
    required this.stepImages,
  });
}

class GuideGenerator {
  static GuideResult generate(List<ColorCluster> colors, LightDirection light) {
    List<PaintingStep> steps = [];
    
    // Assign roles heuristics
    if (colors.isNotEmpty) colors[0].role = 'background';
    if (colors.length > 1) colors[1].role = 'subject';
    if (colors.length > 2) colors[2].role = 'shadow';
    if (colors.length > 3) colors[3].role = 'highlight';
    if (colors.length > 4) colors[4].role = 'structure';
    if (colors.length > 5) colors[5].role = 'detail';
    
    // Limit to 6 colors max per constraints
    final finalColors = colors.take(6).toList();

    // 1. Fondo
    if (finalColors.isNotEmpty) {
      steps.add(PaintingStep(
        title: "Fondo",
        description: "Aplica el color base sobre todo el lienzo. Usa un bloque plano, sin prestar atención a formas ni estructuras. Solo trata de manchar toda la superficie.",
      ));
    }

    // 2. Silueta / Masa principal
    if (finalColors.length > 1) {
      steps.add(PaintingStep(
        title: "Masa principal",
        description: "Fíjate solo en la silueta general del sujeto. Evita pintar ojos, cabello o cualquier detalle interno. Pinta la masa como si fuera una sola mancha o sombra grande.",
      ));
    }

    // 3. Sombras
    if (finalColors.length > 2) {
      String lightOpposite = _getOppositeDirection(light);
      steps.add(PaintingStep(
        title: "Volumen y Sombras",
        description: "Empieza a construir el volumen añadiendo zonas oscuras, principalmente en el lado $lightOpposite. Sigue trabajando con manchas amplias.",
      ));
    }

    // 4. Luces
    if (finalColors.length > 3) {
      String lightStart = LightEstimator.directionToString(light);
      steps.add(PaintingStep(
        title: "Luces",
        description: "Resalta las zonas donde pega la luz (proveniente de la parte $lightStart). Poco a poco vas dando tridimensionalidad al sujeto.",
      ));
    }

    // 5. Estructura
    if (finalColors.length > 4) {
      steps.add(PaintingStep(
        title: "Estructura",
        description: "Usa este paso para definir planos, marcar bordes importantes, contornos faciales y separar formas grandes cruzando líneas tenues.",
      ));
    }

    // 6. Detalles
    if (finalColors.length > 5) {
      steps.add(PaintingStep(
        title: "Detalles finos",
        description: "Finalmente, usa pinceles más delgados para agregar los micro detalles, texturas finas, brillos puntuales o contrastes marcados.",
      ));
    }

    return GuideResult(
      colors: finalColors,
      lightDirection: light,
      steps: steps,
      estimatedTimeMinutes: 45, // Static for MVP
      stepImages: [], // Handled by orchestrator
    );
  }

  static String _getOppositeDirection(LightDirection dir) {
    switch (dir) {
      case LightDirection.topLeft: return "inferior derecha";
      case LightDirection.topRight: return "inferior izquierda";
      case LightDirection.bottomLeft: return "superior derecha";
      case LightDirection.bottomRight: return "superior izquierda";
      case LightDirection.undefined: return "opuesto a la luz principal";
    }
  }
}
