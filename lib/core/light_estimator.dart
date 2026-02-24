import 'package:image/image.dart' as img;

enum LightDirection {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  undefined
}

class LightEstimator {
  /// Estimates light direction by checking the brightest quadrant of the image.
  static LightDirection estimateLightDirection(img.Image image) {
    if (image.width == 0 || image.height == 0) return LightDirection.undefined;

    // We must clone because in some versions of the image package this modifies the original!
    img.Image grayscale = img.grayscale(img.Image.from(image));

    int midX = grayscale.width ~/ 2;
    int midY = grayscale.height ~/ 2;

    double sumTL = 0, sumTR = 0, sumBL = 0, sumBR = 0;
    int countTL = 0, countTR = 0, countBL = 0, countBR = 0;

    // To improve performance, sample pixels (e.g. every 4th pixel)
    // The image should already be downscaled, but let's be safe.
    int sampleRate = 2;

    for (int y = 0; y < grayscale.height; y += sampleRate) {
      for (int x = 0; x < grayscale.width; x += sampleRate) {
        // Luminance is the R, G, or B value (they are equal in grayscale)
        double luminance = grayscale.getPixel(x, y).r.toDouble();

        if (x < midX && y < midY) {
          sumTL += luminance;
          countTL++;
        } else if (x >= midX && y < midY) {
          sumTR += luminance;
          countTR++;
        } else if (x < midX && y >= midY) {
          sumBL += luminance;
          countBL++;
        } else {
          sumBR += luminance;
          countBR++;
        }
      }
    }

    double avgTL = countTL > 0 ? sumTL / countTL : 0;
    double avgTR = countTR > 0 ? sumTR / countTR : 0;
    double avgBL = countBL > 0 ? sumBL / countBL : 0;
    double avgBR = countBR > 0 ? sumBR / countBR : 0;

    double maxAvg = [avgTL, avgTR, avgBL, avgBR].reduce((a, b) => a > b ? a : b);

    if (maxAvg == avgTL) return LightDirection.topLeft;
    if (maxAvg == avgTR) return LightDirection.topRight;
    if (maxAvg == avgBL) return LightDirection.bottomLeft;
    if (maxAvg == avgBR) return LightDirection.bottomRight;

    return LightDirection.undefined;
  }
  
  static String directionToString(LightDirection dir) {
    switch (dir) {
      case LightDirection.topLeft: return "superior izquierda";
      case LightDirection.topRight: return "superior derecha";
      case LightDirection.bottomLeft: return "inferior izquierda";
      case LightDirection.bottomRight: return "inferior derecha";
      case LightDirection.undefined: return "indefinida";
    }
  }
}
