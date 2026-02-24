import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;

import 'image_preprocessor.dart';
import 'color_extractor.dart';
import 'light_estimator.dart';
import 'guide_generator.dart';

class ImageAnalyzer {
  /// Entry point for analysis, intended to be run in an isolate via compute.
  static GuideResult analyze(Uint8List bytes) {
    // 0. Preprocess (Level to Max 1200px, RGB, no alpha)
    final preprocessed = processImageBytes(bytes);
    final baseImage = preprocessed.image;

    // Estimate Light Direction on full image
    final lightDirection = LightEstimator.estimateLightDirection(baseImage);

    // 1. Extract Global Palette (k=6) to get the final colors
    // We lower minPercentage drastically to ensure micro-highlights (like anime eyes) are captured.
    final globalExtraction = ColorExtractor.extractDominantColors(
      baseImage,
      k: 6,
      minPercentage: 0.005, // 0.5% area preserves small glints and highlights
    );
    final globalColors = globalExtraction.dominantColors;
    final guideResultPart = GuideGenerator.generate(globalColors, lightDirection);

    // --- PROGRESSIVE PEDAGOGICAL REDUCTION ALGORITHM ---
    List<Uint8List> stepImages = [];

    for (int stepIndex = 1; stepIndex <= guideResultPart.steps.length; stepIndex++) {
      img.Image stepImg;

      if (stepIndex == 1) {
        // ETAPA 1 - Fondo: Color base constante (c_bg = globalColors[0])
        stepImg = img.Image(width: baseImage.width, height: baseImage.height, numChannels: 3);
        var bg = globalColors.isNotEmpty ? globalColors[0] : ColorCluster(r: 255, g: 255, b: 255, percentage: 1);
        for (var p in stepImg) {
          p.r = bg.r;
          p.g = bg.g;
          p.b = bg.b;
        }
      } 
      else if (stepIndex == 2) {
        // ETAPA 2 - Masa Principal: Downsample fuerte 0.15, Blur 8, KMeans(k=3, minArea=15%)
        stepImg = _processProgressiveStep(
          baseImage, 
          downsampleFactor: 0.15, 
          blurRadius: 8, 
          k: 3, 
          minPercentage: 0.15,
          globalColors: globalColors,
          validClustersCount: 2, // Only allow bg and subject colors
        );
      } 
      else if (stepIndex == 3) {
        // ETAPA 3 - Sombras: Downsample medio 0.35, Blur 4, KMeans(k=4, minArea=8%)
        stepImg = _processProgressiveStep(
          baseImage, 
          downsampleFactor: 0.35, 
          blurRadius: 4, 
          k: 4, 
          minPercentage: 0.08,
           globalColors: globalColors,
           validClustersCount: 3, // Allow bg, subject, shadow
        );
      } 
      else if (stepIndex == 4) {
        // ETAPA 4 - Luces: Downsample leve 0.6, Blur 2, KMeans(k=5, minArea=3%)
        stepImg = _processProgressiveStep(
          baseImage, 
          downsampleFactor: 0.60, 
          blurRadius: 2, 
          k: 5, 
          minPercentage: 0.03,
          globalColors: globalColors,
          validClustersCount: 4, // Allow bg, subject, shadow, highlight
        );
      } 
      else if (stepIndex == 5) {
        // ETAPA 5 - Estructura: Frecuencia media (Formas grandes)
        stepImg = _processProgressiveStep(
          baseImage, 
          downsampleFactor: 0.80, 
          blurRadius: 1, 
          k: 5, 
          minPercentage: 0.01,
          globalColors: globalColors,
          validClustersCount: 5,
        );

        // 1. Blur medio para eliminar microdetalle antes del Sobel
        img.Image blurredForEdges = img.gaussianBlur(baseImage.clone(), radius: 2);

        // 2. Detección profunda de bordes
        img.Image edges = img.sobel(blurredForEdges);
        var shadowColor = globalColors.length > 2 ? globalColors[2] : globalColors[0];

        // 3. Threshold intermedio y mezcla
        for (int y = 0; y < baseImage.height; y++) {
          for (int x = 0; x < baseImage.width; x++) {
             var ep = edges.getPixel(x, y);
             // Magnitud del gradiente
             num mag = ep.r; 
             
             // Thresholding: Si es un borde claro pero no ruido (mag > 45)
             if (mag > 45 && mag < 200) {
                 var sp = stepImg.getPixel(x, y);
                 // Mezcla con baja opacidad (alfa 0.45) usando el color de sombra
                 sp.r = (sp.r * 0.55 + shadowColor.r * 0.45).floor();
                 sp.g = (sp.g * 0.55 + shadowColor.g * 0.45).floor();
                 sp.b = (sp.b * 0.55 + shadowColor.b * 0.45).floor();
             }
          }
        }
      }
      else {
        // ETAPA 6 - Detalles Finos: High-Freq + Bright Flat Region Reinforcement
        
        // Base será la imagen de la etapa 5 para acumular
        stepImg = img.Image.from(stepImages.isNotEmpty ? img.decodePng(stepImages.last)! : baseImage);
        
        // 1. Blur fuerte para separar frecuencias
        img.Image blurred = img.gaussianBlur(baseImage.clone(), radius: 4);

        // 2. Preparar acumuladores para threshold adaptativo y luminancia global
        List<double> magnitudes = [];
        List<double> luminances = [];

        // 3. Calcular high-pass positivo, magnitud y luminancia perceptual
        for (int y = 0; y < baseImage.height; y++) {
          for (int x = 0; x < baseImage.width; x++) {
            final orig = baseImage.getPixel(x, y);
            final blur = blurred.getPixel(x, y);

            int rDiff = max(0, (orig.r - blur.r).toInt());
            int gDiff = max(0, (orig.g - blur.g).toInt());
            int bDiff = max(0, (orig.b - blur.b).toInt());

            double magnitude = sqrt(
              rDiff * rDiff +
              gDiff * gDiff +
              bDiff * bDiff
            );
            magnitudes.add(magnitude);

            // Luminancia perceptual real (Rec. 709)
            double luma = 0.299 * orig.r + 0.587 * orig.g + 0.114 * orig.b;
            luminances.add(luma);
          }
        }

        // 4. Threshold adaptativo para high-pass (mean + 1.2 * std)
        double magSum = 0;
        for (var m in magnitudes) { magSum += m; }
        double magMean = magSum / magnitudes.length;
        double magVarSum = 0;
        for (var m in magnitudes) { magVarSum += pow(m - magMean, 2); }
        double magStd = sqrt(magVarSum / magnitudes.length);
        double threshold = magMean + 1.2 * magStd;

        // 5. Stats de luminancia global para detectar "bright flat" regions
        double lumaSum = 0;
        for (var l in luminances) { lumaSum += l; }
        double globalMeanLuma = lumaSum / luminances.length;
        double lumaVarSum = 0;
        for (var l in luminances) { lumaVarSum += pow(l - globalMeanLuma, 2); }
        double globalLumaStd = sqrt(lumaVarSum / luminances.length);
        double brightFlatThreshold = globalMeanLuma + globalLumaStd * 0.8;

        // 6. Aplicar ambas ramas por pixel
        const double gain = 1.8; // intensidad high-pass

        for (int y = 0; y < baseImage.height; y++) {
          for (int x = 0; x < baseImage.width; x++) {
            int i = y * baseImage.width + x;
            double magnitude = magnitudes[i];
            double luma = luminances[i];

            final orig = baseImage.getPixel(x, y);
            var sp = stepImg.getPixel(x, y);

            // RAMA A: High-frequency microdetalle / bordes / textura
            if (magnitude > threshold) {
              final blur = blurred.getPixel(x, y);
              int rDiff = max(0, (orig.r - blur.r).toInt());
              int gDiff = max(0, (orig.g - blur.g).toInt());
              int bDiff = max(0, (orig.b - blur.b).toInt());

              sp.r = min(255, (orig.r + (rDiff * gain)).toInt());
              sp.g = min(255, (orig.g + (gDiff * gain)).toInt());
              sp.b = min(255, (orig.b + (bDiff * gain)).toInt());
            }
            // RAMA B: Bright flat region (anime highlights)
            // Pixel muy brillante pero no borde fuerte → mechón blanco plano
            else if (luma > brightFlatThreshold && magnitude < threshold * 0.6) {
              sp.r = min(255, orig.r.toInt() + 25);
              sp.g = min(255, orig.g.toInt() + 25);
              sp.b = min(255, orig.b.toInt() + 25);
            }
          }
        }
      }

      stepImages.add(img.encodePng(stepImg));
    }

    return GuideResult(
      colors: guideResultPart.colors,
      lightDirection: guideResultPart.lightDirection,
      steps: guideResultPart.steps,
      estimatedTimeMinutes: guideResultPart.estimatedTimeMinutes,
      stepImages: stepImages,
    );
  }

  static img.Image _processProgressiveStep(
    img.Image baseImage, {
    required double downsampleFactor,
    required int blurRadius,
    required int k,
    required double minPercentage,
    required List<ColorCluster> globalColors,
    required int validClustersCount,
  }) {
    // 1. Downsample safely using aspect-ratio aware sizing
    int smallW = (baseImage.width * downsampleFactor).toInt();
    int smallH = (baseImage.height * downsampleFactor).toInt();
    if (smallW <= 0 || smallH <= 0) return baseImage;

    img.Image downsampled = img.copyResize(baseImage, width: smallW, height: smallH, interpolation: img.Interpolation.average);

    // 2. Gaussian Blur
    img.Image blurred = img.gaussianBlur(downsampled, radius: blurRadius);

    // 3. Extracción de Colores Regionales y Mapa de Píxeles
    var extraction = ColorExtractor.extractDominantColors(
      blurred,
      k: k,
      minPercentage: minPercentage,
    );

    // To prevent banding, map using actual extracted dimensions
    int exW = extraction.width;
    int exH = extraction.height;
    
    // Creamos la imagen en baja resolución mapeando a la PALETA GLOBAL estricta
    img.Image stepLowRes = img.Image(width: exW, height: exH, numChannels: 3);
    var assignments = extraction.pixelAssignments;
    var localColors = extraction.dominantColors;

    for (int y = 0; y < exH; y++) {
      for (int x = 0; x < exW; x++) {
        int p = y * exW + x;
        if (p < assignments.length) {
          int localId = assignments[p];
          if (localId >= localColors.length) localId = 0;
          var lc = localColors[localId];
          
          // Mapear el color local encontrado al color GLOBAL permitido más cercano
          int bestGlobalId = 0;
          double minD = double.infinity;
          for (int g = 0; g < validClustersCount && g < globalColors.length; g++) {
             var gc = globalColors[g];
             double d = _dist(lc.r, lc.g, lc.b, gc.r, gc.g, gc.b);
             if (d < minD) {
                minD = d;
                bestGlobalId = g;
             }
          }
  
          var f = globalColors[bestGlobalId];
          stepLowRes.setPixelRgb(x, y, f.r, f.g, f.b);
        }
      }
    }

    // 4. Upscale a resolución final, con interpolación Nearest 
    // (para mantener los bordes del blob "pintable" sin bands/aliasing extras)
    img.Image upscaled = img.copyResize(stepLowRes, width: baseImage.width, height: baseImage.height, interpolation: img.Interpolation.nearest);

    return upscaled;
  }

  static double _dist(int r1, int g1, int b1, int r2, int g2, int b2) {
     return ((r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2)).toDouble();
  }
}
