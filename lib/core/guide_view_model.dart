import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'image_analyzer.dart';
import 'color_extractor.dart';
import 'guide_generator.dart';
import 'light_estimator.dart';
import 'app_strings.dart';
import 'image_preprocessor.dart';

enum ViewState {
  idle,
  loading,
  loaded,
  error,
}

// Update this to your deployed backend URL (e.g. Railway or Fly.io)
const String kApiUrl = 'https://rossidifier-api-production.up.railway.app';

class GuideViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  ViewState get state => _state;

  Uint8List? _selectedImageBytes;
  Uint8List? get selectedImageBytes => _selectedImageBytes;

  GuideResult? _guideResult;
  GuideResult? get guideResult => _guideResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _complexity = 6;
  int get complexity => _complexity;

  void setComplexity(int value) {
    if (value >= 3 && value <= 10) {
      _complexity = value;
      notifyListeners();
    }
  }

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

      final guide = await _callAnalysisApi(bytes, baseK: _complexity);
      _guideResult = guide;
      _setState(ViewState.loaded);
    } catch (e) {
      debugPrint('Error: $e');
      _setError('Error al conectar con el servidor de análisis.');
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

        if (bytes.lengthInBytes > 50 * 1024 * 1024) {
          _setError('La imagen excede el límite de 50MB.');
          return;
        }

        _selectedImageBytes = bytes;
        _setState(ViewState.loading);
        await Future.delayed(const Duration(milliseconds: 80));

        // Compress highly so we save bandwidth to Railway API
        final compressedBytes = await compute(compressImageBytes, bytes);
        _selectedImageBytes = compressedBytes;

        final guide = await _callAnalysisApi(compressedBytes, baseK: _complexity);

        _guideResult = guide;
        _setState(ViewState.loaded);
      }
    } catch (e) {
      debugPrint('Error: $e');
      _setError('Error en el servidor de análisis. Inténtalo de nuevo.');
    }
  }

  Future<void> overrideColor(int index, Color newColor) async {
    if (_selectedImageBytes == null || _guideResult == null) return;
    if (index < 0 || index >= _guideResult!.colors.length) return;

    _setState(ViewState.loading);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final modifiedColors = List<ColorCluster>.from(_guideResult!.colors);
      final old = modifiedColors[index];
      modifiedColors[index] = ColorCluster(
        r: newColor.red, 
        g: newColor.green, 
        b: newColor.blue, 
        percentage: old.percentage, 
        role: old.role
      );

      final newGuide = await _callAnalysisApi(
        _selectedImageBytes!, 
        baseK: _guideResult!.colors.length,
        forcedColors: modifiedColors,
      );

      _guideResult = newGuide;
      _setState(ViewState.loaded);
    } catch (e) {
      debugPrint('Override Error: $e');
      _setError('Error de comunicación con el servidor.');
    }
  }

  Future<GuideResult> _callAnalysisApi(Uint8List bytes, {int baseK = 6, List<ColorCluster>? forcedColors}) async {
    try {
      final payload = {
        'image': base64Encode(bytes),
        'baseK': baseK,
        if (forcedColors != null) 'forcedColors': forcedColors.map((c) => {
          'r': c.r,
          'g': c.g,
          'b': c.b,
          'percentage': c.percentage,
          'role': c.role,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$kApiUrl/analyze'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': const String.fromEnvironment('API_KEY'),
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Map back to classes
        final colors = (data['colors'] as List).map((c) => ColorCluster(
          r: c['r'],
          g: c['g'],
          b: c['b'],
          percentage: c['percentage'],
          role: c['role'],
        )).toList();

        final steps = (data['steps'] as List).map((s) => PaintingStep(
          stepKey: StepKey.values.firstWhere((e) => e.name == s['stepKey']),
          lightDir: s['lightDir'],
          lightOpp: s['lightOpp'],
        )).toList();

        return GuideResult(
          colors: colors,
          lightDirection: LightDirection.values.firstWhere((e) => e.name == data['lightDirection']),
          steps: steps,
          estimatedTimeMinutes: data['estimatedTimeMinutes'],
          stepImages: (data['stepImages'] as List).map((s) => base64Decode(s)).toList(),
          cumulativeStepImages: (data['cumulativeStepImages'] as List).map((s) => base64Decode(s)).toList(),
        );
      } else {
        debugPrint('Server returned ${response.statusCode}: ${response.body}. Falling back to local...');
      }
    } catch (e) {
      debugPrint('API Error: $e. Falling back to local analysis...');
    }

    // Fallback to local analysis using compute
    return await compute(
      ImageAnalyzer.analyzeParams, 
      AnalysisParams(bytes: bytes, baseK: baseK, forcedColors: forcedColors),
    );
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
