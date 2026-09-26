import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Top-level function — safe to run inside a Flutter compute() isolate.
/// Encodes a list of PNG frames into an animated GIF (loops forever).
Future<Uint8List> encodeAnimatedGif(List<Uint8List> pngFrames) async {
  const int maxWidth = 480; // keep GIF file size reasonable
  const int frameDelay = 120; // 1.2 sec per frame in centiseconds

  final encoder = img.GifEncoder(repeat: 0, delay: frameDelay);

  for (final pngBytes in pngFrames) {
    await Future.delayed(const Duration(milliseconds: 10));
    var frame = img.decodePng(pngBytes);
    if (frame == null) continue;

    // Resize proportionally if too wide
    if (frame.width > maxWidth) {
      final newH = (frame.height * maxWidth / frame.width).round();
      frame = img.copyResize(frame, width: maxWidth, height: newH,
          interpolation: img.Interpolation.average);
    }
    
    await Future.delayed(const Duration(milliseconds: 10));
    encoder.addFrame(frame);
  }

  await Future.delayed(const Duration(milliseconds: 10));
  return Uint8List.fromList(encoder.finish() ?? []);
}
