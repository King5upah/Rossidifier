import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;

import 'image_preprocessor.dart';
import 'color_extractor.dart';
import 'light_estimator.dart';
import 'guide_generator.dart';

class AnalysisParams {
  final Uint8List bytes;
  final int baseK;
  final List<ColorCluster>? forcedColors;

  AnalysisParams({
    required this.bytes,
    this.baseK = 6,
    this.forcedColors,
  });
}

class ImageAnalyzer {
  /// Internal logic helper for isolates
  static GuideResult analyzeParams(AnalysisParams params) {
    return _analyzeSync(params.bytes, baseK: params.baseK, forcedColors: params.forcedColors);
  }

  /// Original entry point (now wrapper for sync logic)
  static Future<GuideResult> analyze(Uint8List bytes, {int baseK = 6, List<ColorCluster>? forcedColors}) async {
    return _analyzeSync(bytes, baseK: baseK, forcedColors: forcedColors);
  }

  static GuideResult _analyzeSync(Uint8List bytes, {int baseK = 6, List<ColorCluster>? forcedColors}) {
    // 0. Preprocess (Level to Max 1200px, RGB, no alpha)
    final preprocessed = processImageBytes(bytes);
    final baseImage = preprocessed.image;

    // Estimate Light Direction on full image
    final lightDirection = LightEstimator.estimateLightDirection(baseImage);

    // 1. Extract Global Palette (k=6) to get the final colors or use forced overrides
    List<ColorCluster> globalColors;
    if (forcedColors != null && forcedColors.isNotEmpty) {
      globalColors = List.from(forcedColors);
    } else {
      final globalExtraction = ColorExtractor.extractDominantColors(
        baseImage,
        k: baseK,
        minPercentage: 0.005,
      );
      globalColors = globalExtraction.dominantColors;
    }
    final guideResultPart = GuideGenerator.generate(globalColors, lightDirection, maxColors: baseK);

    // --- PROGRESSIVE PEDAGOGICAL REDUCTION ALGORITHM ---
    List<Uint8List> stepImages = [];

    for (int stepIndex = 1; stepIndex <= guideResultPart.steps.length; stepIndex++) {
      img.Image stepImg;

      if (stepIndex == 1) {
        // Step 1 - Background
        stepImg = img.Image(width: baseImage.width, height: baseImage.height, numChannels: 3);
        var bg = globalColors.isNotEmpty ? globalColors[0] : ColorCluster(r: 255, g: 255, b: 255, percentage: 1);
        for (var p in stepImg) {
          p.r = bg.r;
          p.g = bg.g;
          p.b = bg.b;
        }
      } 
      else if (stepIndex == 2) {
        // Step 2 - Main Mass
        stepImg = _processProgressiveStepSync(
          baseImage, 
          downsampleFactor: 0.15, 
          blurRadius: 8, 
          k: 3, 
          minPercentage: 0.15,
          globalColors: globalColors,
          validClustersCount: 2,
        );
      } 
      else if (stepIndex == 3) {
        // Step 3 - Shadows
        stepImg = _processProgressiveStepSync(
          baseImage, 
          downsampleFactor: 0.35, 
          blurRadius: 4, 
          k: 4, 
          minPercentage: 0.08,
           globalColors: globalColors,
           validClustersCount: 3,
        );
      } 
      else if (stepIndex == 4) {
        // Step 4 - Lights
        stepImg = _processProgressiveStepSync(
          baseImage, 
          downsampleFactor: 0.60, 
          blurRadius: 2, 
          k: 5, 
          minPercentage: 0.03,
          globalColors: globalColors,
          validClustersCount: 4,
        );
      } 
      else if (stepIndex == 5) {
        // Step 5 - Structure
        stepImg = _processProgressiveStepSync(
          baseImage, 
          downsampleFactor: 0.80, 
          blurRadius: 1, 
          k: 5, 
          minPercentage: 0.01,
          globalColors: globalColors,
          validClustersCount: 5,
        );

        img.Image blurredForEdges = img.gaussianBlur(baseImage.clone(), radius: 2);
        img.Image edges = img.sobel(blurredForEdges);
        var shadowColor = globalColors.length > 2 ? globalColors[2] : globalColors[0];

        for (int y = 0; y < baseImage.height; y++) {
          for (int x = 0; x < baseImage.width; x++) {
             var ep = edges.getPixel(x, y);
             num mag = ep.r; 
             if (mag > 45 && mag < 200) {
                 var sp = stepImg.getPixel(x, y);
                 sp.r = (sp.r * 0.55 + shadowColor.r * 0.45).floor();
                 sp.g = (sp.g * 0.55 + shadowColor.g * 0.45).floor();
                 sp.b = (sp.b * 0.55 + shadowColor.b * 0.45).floor();
             }
          }
        }
      }
      else {
        // Step 6 - Details
        stepImg = img.Image.from(stepImages.isNotEmpty ? img.decodePng(stepImages.last)! : baseImage);
        img.Image blurred = img.gaussianBlur(baseImage.clone(), radius: 4);

        List<double> magnitudes = [];
        List<double> luminances = [];

        for (int y = 0; y < baseImage.height; y++) {
          for (int x = 0; x < baseImage.width; x++) {
            final orig = baseImage.getPixel(x, y);
            final blur = blurred.getPixel(x, y);

            int rDiff = max(0, (orig.r - blur.r).toInt());
            int gDiff = max(0, (orig.g - blur.g).toInt());
            int bDiff = max(0, (orig.b - blur.b).toInt());

            double magnitude = sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff);
            magnitudes.add(magnitude);

            double luma = 0.299 * orig.r + 0.587 * orig.g + 0.114 * orig.b;
            luminances.add(luma);
          }
        }

        double magSum = 0;
        for (var m in magnitudes) { magSum += m; }
        double magMean = magSum / magnitudes.length;
        double magVarSum = 0;
        for (var m in magnitudes) { magVarSum += pow(m - magMean, 2); }
        double magStd = sqrt(magVarSum / magnitudes.length);
        double threshold = magMean + 1.2 * magStd;

        double lumaSum = 0;
        for (var l in luminances) { lumaSum += l; }
        double globalMeanLuma = lumaSum / luminances.length;
        double lumaVarSum = 0;
        for (var l in luminances) { lumaVarSum += pow(l - globalMeanLuma, 2); }
        double globalLumaStd = sqrt(lumaVarSum / luminances.length);
        double brightFlatThreshold = globalMeanLuma + globalLumaStd * 0.8;

        const double gain = 1.8;

        for (int y = 0; y < baseImage.height; y++) {
          for (int x = 0; x < baseImage.width; x++) {
            int i = y * baseImage.width + x;
            double magnitude = magnitudes[i];
            double luma = luminances[i];
            final orig = baseImage.getPixel(x, y);
            var sp = stepImg.getPixel(x, y);

            if (magnitude > threshold) {
              final blur = blurred.getPixel(x, y);
              int rDiff = max(0, (orig.r - blur.r).toInt());
              int gDiff = max(0, (orig.g - blur.g).toInt());
              int bDiff = max(0, (orig.b - blur.b).toInt());
              sp.r = min(255, (orig.r + (rDiff * gain)).toInt());
              sp.g = min(255, (orig.g + (gDiff * gain)).toInt());
              sp.b = min(255, (orig.b + (bDiff * gain)).toInt());
            }
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

    // Cumulative pass
    final ColorCluster bgColor = globalColors.isNotEmpty ? globalColors[0] : ColorCluster(r: 255, g: 255, b: 255, percentage: 1);
    double bgSubjectDist = globalColors.length > 1 ? _dist(bgColor.r, bgColor.g, bgColor.b, globalColors[1].r, globalColors[1].g, globalColors[1].b) : 900.0;
    final double compositeThr = max(200.0, bgSubjectDist * 0.35);

    List<Uint8List> cumulativeImages = [];
    img.Image? prevCumCanvas;

    for (int i = 0; i < stepImages.length; i++) {
        final img.Image snap = img.decodePng(stepImages[i])!;
        if (i == 0) {
            cumulativeImages.add(stepImages[0]);
            prevCumCanvas = img.Image.from(snap);
        } else {
            final img.Image cumCanvas = img.Image.from(prevCumCanvas!);
            for (int y = 0; y < cumCanvas.height; y++) {
                for (int x = 0; x < cumCanvas.width; x++) {
                    final sp = snap.getPixel(x, y);
                    final distToBg = _dist(sp.r.toInt(), sp.g.toInt(), sp.b.toInt(), bgColor.r, bgColor.g, bgColor.b);
                    if (distToBg > compositeThr) {
                        final cp = cumCanvas.getPixel(x, y);
                        cp.r = sp.r;
                        cp.g = sp.g;
                        cp.b = sp.b;
                    }
                }
            }
            cumulativeImages.add(Uint8List.fromList(img.encodePng(cumCanvas)));
            prevCumCanvas = cumCanvas;
        }
    }

    return GuideResult(
      colors: guideResultPart.colors,
      lightDirection: guideResultPart.lightDirection,
      steps: guideResultPart.steps,
      estimatedTimeMinutes: guideResultPart.estimatedTimeMinutes,
      stepImages: stepImages,
      cumulativeStepImages: cumulativeImages,
    );
  }

  static img.Image _processProgressiveStepSync(
    img.Image baseImage, {
    required double downsampleFactor,
    required int blurRadius,
    required int k,
    required double minPercentage,
    required List<ColorCluster> globalColors,
    required int validClustersCount,
  }) {
    int smallW = (baseImage.width * downsampleFactor).toInt();
    int smallH = (baseImage.height * downsampleFactor).toInt();
    if (smallW <= 0 || smallH <= 0) return baseImage;
    img.Image downsampled = img.copyResize(baseImage, width: smallW, height: smallH, interpolation: img.Interpolation.average);
    img.Image blurred = img.gaussianBlur(downsampled, radius: blurRadius);

    var extraction = ColorExtractor.extractDominantColors(blurred, k: k, minPercentage: minPercentage);
    int exW = extraction.width;
    int exH = extraction.height;
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
          int bestGlobalId = 0;
          double minD = double.infinity;
          for (int g = 0; g < validClustersCount && g < globalColors.length; g++) {
             var gc = globalColors[g];
             double d = _dist(lc.r, lc.g, lc.b, gc.r, gc.g, gc.b);
             if (d < minD) { minD = d; bestGlobalId = g; }
          }
          var f = globalColors[bestGlobalId];
          stepLowRes.setPixelRgb(x, y, f.r, f.g, f.b);
        }
      }
    }
    return img.copyResize(stepLowRes, width: baseImage.width, height: baseImage.height, interpolation: img.Interpolation.nearest);
  }

  static double _dist(int r1, int g1, int b1, int r2, int g2, int b2) {
     return ((r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2)).toDouble();
  }
}
