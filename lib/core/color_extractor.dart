import 'dart:math';
import 'package:image/image.dart' as img;

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
}

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

class ColorExtractor {
  /// Extracts dominant colors and returns a cluster assignment per pixel
  static ColorExtractionResult extractDominantColors(
    img.Image image, {
    int k = 5,
    double minPercentage = 0.05,
    int maxIterations = 20,
  }) {
    // For previews, we resize the image if it is too large 
    // to keep pixel mapping manageable (e.g. max 600)
    int mw = 600;
    img.Image workImage = image;
    if (workImage.width > mw || workImage.height > mw) {
      if (workImage.width > workImage.height) {
        workImage = img.copyResize(workImage, width: mw);
      } else {
        workImage = img.copyResize(workImage, height: mw);
      }
    }

    List<_Point> pixels = [];
    for (int y = 0; y < workImage.height; y++) {
      for (int x = 0; x < workImage.width; x++) {
        var p = workImage.getPixel(x, y);
        pixels.add(_Point(p.r.toDouble(), p.g.toDouble(), p.b.toDouble(), x, y));
      }
    }

    if (pixels.isEmpty) {
      return ColorExtractionResult(dominantColors: [], pixelAssignments: [], width: 0, height: 0);
    }

    final random = Random(42);
    List<_Point> centroids = [];
    for (int i = 0; i < k; i++) {
      centroids.add(pixels[random.nextInt(pixels.length)]);
    }

    List<int> assignments = List.filled(pixels.length, 0);
    bool changed = true;
    int iteration = 0;

    while (changed && iteration < maxIterations) {
      changed = false;
      iteration++;

      for (int i = 0; i < pixels.length; i++) {
        int bestCluster = 0;
        double minDistance = double.infinity;
        for (int j = 0; j < k; j++) {
          double dist = _distance(pixels[i], centroids[j]);
          if (dist < minDistance) {
            minDistance = dist;
            bestCluster = j;
          }
        }
        if (assignments[i] != bestCluster) {
          assignments[i] = bestCluster;
          changed = true;
        }
      }

      List<_Point> newCentroids = List.generate(k, (_) => _Point(0, 0, 0, 0, 0));
      List<int> counts = List.generate(k, (_) => 0);

      for (int i = 0; i < pixels.length; i++) {
        int cluster = assignments[i];
        newCentroids[cluster].r += pixels[i].r;
        newCentroids[cluster].g += pixels[i].g;
        newCentroids[cluster].b += pixels[i].b;
        counts[cluster]++;
      }

      for (int j = 0; j < k; j++) {
        if (counts[j] > 0) {
          centroids[j] = _Point(
            newCentroids[j].r / counts[j],
            newCentroids[j].g / counts[j],
            newCentroids[j].b / counts[j],
             0, 0
          );
        } else {
          centroids[j] = pixels[random.nextInt(pixels.length)];
        }
      }
    }

    // Now count and map the 'k' raw clusters into final filtered clusters
    List<int> counts = List.generate(k, (_) => 0);
    for (int cluster in assignments) {
      counts[cluster]++;
    }

    int totalPixels = pixels.length;
    List<_RawCluster> rawClusters = [];
    for (int j = 0; j < k; j++) {
      double percentage = counts[j] / totalPixels;
      rawClusters.add(_RawCluster(
        id: j,
        r: centroids[j].r.round(),
        g: centroids[j].g.round(),
        b: centroids[j].b.round(),
        percentage: percentage,
      ));
    }

    // Filter and sort accepted clusters
    var acceptedClusters = rawClusters.where((c) => c.percentage >= minPercentage).toList();
    acceptedClusters.sort((a, b) => b.percentage.compareTo(a.percentage));
    // Limit to 6
    if (acceptedClusters.length > 6) {
      acceptedClusters = acceptedClusters.take(6).toList();
    }
    
    // Map discarded clusters to the nearest accepted cluster
    Map<int, int> rawIdToFinalId = {};
    for (int j = 0; j < k; j++) {
      if (acceptedClusters.any((c) => c.id == j)) {
        rawIdToFinalId[j] = acceptedClusters.indexWhere((c) => c.id == j);
      } else {
        // find nearest accepted
        if (acceptedClusters.isEmpty) {
           rawIdToFinalId[j] = 0; // fallback if all were discarded (rare)
        } else {
           _RawCluster rc = rawClusters[j];
           int bestFinalId = 0;
           double minD = double.infinity;
           for(int f=0; f < acceptedClusters.length; f++){
               var ac = acceptedClusters[f];
               double d = _distColor(rc.r, rc.g, rc.b, ac.r, ac.g, ac.b);
               if(d < minD) {
                   minD = d;
                   bestFinalId = f;
               }
           }
           rawIdToFinalId[j] = bestFinalId;
        }
      }
    }

    // Rewrite assignments to the final indices
    List<int> finalAssignments = List.filled(pixels.length, 0);
    for(int i = 0; i < pixels.length; i++) {
       int rawClusterId = assignments[i];
       int finalId = rawIdToFinalId[rawClusterId] ?? 0;
       finalAssignments[i] = finalId;
    }

    // Map to final domain object
    List<ColorCluster> finalColors = acceptedClusters.map((c) => ColorCluster(
        r: c.r, g: c.g, b: c.b, percentage: c.percentage 
    )).toList();

    return ColorExtractionResult(
      dominantColors: finalColors,
      pixelAssignments: finalAssignments,
      width: workImage.width,
      height: workImage.height,
    );
  }
  
  static double _distColor(int r1, int g1, int b1, int r2, int g2, int b2) {
    return ((r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2)).toDouble();
  }

  static double _distance(_Point a, _Point b) {
    return (a.r - b.r) * (a.r - b.r) + 
           (a.g - b.g) * (a.g - b.g) + 
           (a.b - b.b) * (a.b - b.b);
  }
}

class _RawCluster {
  final int id;
  final int r, g, b;
  final double percentage;
  _RawCluster({required this.id, required this.r, required this.g, required this.b, required this.percentage});
}

class _Point {
  double r;
  double g;
  double b;
  int x;
  int y;

  _Point(this.r, this.g, this.b, this.x, this.y);
}
