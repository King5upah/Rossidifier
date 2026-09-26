import 'package:flutter/material.dart';
import 'dart:math' as math;

class PaintingUtils {
  /// Estimates physical paint mixing formulas (Simplified RYB/Subtractive)
  static String getPaintMix(Color c) {
    int r = c.red;
    int g = c.green;
    int b = c.blue;
    double lum = c.computeLuminance();
    
    // Grayscale checks
    if ((r - g).abs() < 15 && (g - b).abs() < 15) {
      if (lum > 0.8) return '100% Titanium White';
      if (lum < 0.2) return '100% Mars Black';
      return '${(lum * 100).toInt()}% White + ${(100 - (lum * 100)).toInt()}% Black';
    }

    // Subtractive estimation (Simplified RYB)
    double redPart = r / 255.0;
    double greenPart = g / 255.0;
    double bluePart = b / 255.0;

    // White addition estimation
    double whiteMix = [redPart, greenPart, bluePart].reduce(math.min);
    
    // Saturation extraction
    double rS = redPart - whiteMix;
    double gS = greenPart - whiteMix;
    double bS = bluePart - whiteMix;

    String primary = '';
    if (rS > gS && rS > bS) {
      primary = gS > bS ? 'Cadmium Red + Yellow' : 'Alizarin Crimson + Blue';
    } else if (gS > rS && gS > bS) {
      primary = rS > bS ? 'Sap Green + Red' : 'Phthalo Green + Blue';
    } else {
      primary = rS > gS ? 'Ultramarine Blue + Red' : 'Cerulean Blue + Yellow';
    }

    if (whiteMix > 0.4) {
      if (whiteMix > 0.7) return 'Mostly White w/ $primary';
      return '50% Titanium White + $primary';
    } else if (lum < 0.2) {
      return '$primary + Burnt Umber';
    }

    return primary;
  }
}
