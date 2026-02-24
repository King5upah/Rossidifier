import 'dart:typed_data';
import 'package:image/image.dart' as img;

class PreprocessedImage {
  final img.Image image;
  final int width;
  final int height;

  PreprocessedImage(this.image)
      : width = image.width,
        height = image.height;
}

/// Runs the image preprocessing in an isolate
PreprocessedImage processImageBytes(Uint8List bytes) {
  // Decode the image. This auto-detects JPEG, PNG, etc.
  img.Image? originalImage = img.decodeImage(bytes);

  if (originalImage == null) {
    throw Exception('No se pudo decodificar la imagen. Formato no soportado o archivo corrupto.');
  }

  // 1. Resize if needed
  img.Image processed = originalImage;
  const int maxDimension = 1200;

  if (processed.width > maxDimension || processed.height > maxDimension) {
    // Proportional resize
    if (processed.width > processed.height) {
      processed = img.copyResize(processed, width: maxDimension);
    } else {
      processed = img.copyResize(processed, height: maxDimension);
    }
  }

  // 2. Remove Alpha channel properly
  // Since some image decoders apply alpha to RGB (or default to transparent = black),
  // we draw the image over a solid white background.
  if (processed.hasAlpha) {
    img.Image whiteBg = img.Image(
      width: processed.width,
      height: processed.height,
      numChannels: 3,
    );
    // Fill with white
    for (var p in whiteBg) {
      p.r = 255;
      p.g = 255;
      p.b = 255;
    }
    // Composite the decoded image over the white background
    img.compositeImage(whiteBg, processed, dstX: 0, dstY: 0);
    processed = whiteBg;
  }

  return PreprocessedImage(processed);
}
