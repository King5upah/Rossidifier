import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../lib/core/image_analyzer.dart';
import '../lib/models.dart';

// Configure routes
final _router = Router()
  ..get('/health', _healthHandler)
  ..post('/analyze', _analyzeHandler);

Response _healthHandler(Request request) {
  return Response.ok(jsonEncode({'status': 'ok', 'version': '1.6.0'}));
}

Future<Response> _analyzeHandler(Request request) async {
  try {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    if (data['image'] == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Missing image data'}));
    }

    final Uint8List bytes = base64Decode(data['image']);
    final int baseK = data['baseK'] ?? 6;
    
    List<ColorCluster>? forcedColors;
    if (data['forcedColors'] != null) {
      forcedColors = (data['forcedColors'] as List).map((c) => ColorCluster(
        r: c['r'],
        g: c['g'],
        b: c['b'],
        percentage: c['percentage'],
        role: c['role'],
      )).toList();
    }

    final result = ImageAnalyzer.analyze(bytes, baseK: baseK, forcedColors: forcedColors);

    // Convert result to JSON-friendly map
    final responseData = {
      'colors': result.colors.map((c) => c.toJson()).toList(),
      'steps': result.steps.map((s) => s.toJson()).toList(),
      'estimatedTimeMinutes': result.estimatedTimeMinutes,
      'lightDirection': result.lightDirection.name,
      'stepImages': result.stepImages.map((img) => base64Encode(img)).toList(),
      'cumulativeStepImages': result.cumulativeStepImages.map((img) => base64Encode(img)).toList(),
    };

    return Response.ok(jsonEncode(responseData), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('Error in /analyze: $e');
    return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
  }
}

void main(List<String> args) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final expectedApiKey = Platform.environment['API_KEY'] ?? Platform.environment['ROSSIDIFIER_API_KEY'];

  if (expectedApiKey == null || expectedApiKey.isEmpty) {
    print('WARNING: ROSSIDIFIER_API_KEY is not set. API is UNPROTECTED.');
  }

  // Middleware to check for the API key in headers
  Middleware apiKeyMiddleware() {
    return (innerHandler) {
      return (request) async {
        // Skip check for health or OPTIONS (CORS)
        if (request.url.path == 'health' || request.method == 'OPTIONS') {
          return innerHandler(request);
        }

        final providedKey = request.headers['x-api-key'];
        if (expectedApiKey != null && expectedApiKey.isNotEmpty && providedKey != expectedApiKey) {
          return Response.forbidden(jsonEncode({'error': 'Unauthorized: Invalid or missing API Key'}));
        }

        return innerHandler(request);
      };
    };
  }

  // Manual CORS Middleware to handle preflight and headers correctly
  Middleware manualCors() {
    return (innerHandler) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept, x-api-key',
            'Access-Control-Max-Age': '86400',
          });
        }

        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept, x-api-key',
        });
      };
    };
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(manualCors())
      .addMiddleware(apiKeyMiddleware())
      .addHandler(_router.call);

  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}
