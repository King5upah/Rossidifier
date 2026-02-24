import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'image_analyzer.dart';
import 'guide_generator.dart';

enum ViewState {
  idle,
  loading,
  loaded,
  error,
}

class GuideViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  ViewState get state => _state;

  Uint8List? _selectedImageBytes;
  Uint8List? get selectedImageBytes => _selectedImageBytes;

  GuideResult? _guideResult;
  GuideResult? get guideResult => _guideResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isProcessing => _state == ViewState.loading;

  Future<void> processImageFromUrl(String url) async {
    _errorMessage = null;
    _guideResult = null;
    _setState(ViewState.loading);
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _setError('No se pudo cargar la imagen demo.');
        return;
      }
      final bytes = response.bodyBytes;
      _selectedImageBytes = bytes;
      notifyListeners();

      final guide = await ImageAnalyzer.analyze(bytes);
      _guideResult = guide;
      _setState(ViewState.loaded);
    } catch (e) {
      debugPrint('Error: $e');
      _setError('Error al cargar la imagen demo.');
    }
  }

  Future<void> pickAndProcessImage() async {
    _setState(ViewState.idle);
    _errorMessage = null;
    _guideResult = null;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes == null) {
          _setError('No se pudo leer la imagen.');
          return;
        }

        if (bytes.lengthInBytes > 10 * 1024 * 1024) {
          _setError('La imagen excede el límite de 10MB.');
          return;
        }

        _selectedImageBytes = bytes;
        _setState(ViewState.loading);

        // Yield to the Flutter event loop so the loading overlay can paint
        // before compute() blocks the main thread (on Flutter Web, compute runs
        // on the same thread and can starve the UI if we don't flush first).
        await Future.delayed(const Duration(milliseconds: 80));

        // Run analysis in an isolate
        final guide = await ImageAnalyzer.analyze(bytes);

        _guideResult = guide;
        _setState(ViewState.loaded);
      }
    } catch (e) {
      debugPrint('Error: $e');
      _setError('Error al analizar la imagen. Quizá sea muy grande o corrupta.');
    }
  }
  
  void _setError(String message) {
    _errorMessage = message;
    _setState(ViewState.error);
  }

  void _setState(ViewState newState) {
    _state = newState;
    notifyListeners();
  }
}
