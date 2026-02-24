import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/guide_view_model.dart';
import 'core/guide_generator.dart';

void main() {
  runApp(const PaintGuideApp());
}

class PaintGuideApp extends StatelessWidget {
  const PaintGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PaintGuide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const GuideHomePage(),
    );
  }
}

class GuideHomePage extends StatefulWidget {
  const GuideHomePage({super.key});

  @override
  State<GuideHomePage> createState() => _GuideHomePageState();
}

class _GuideHomePageState extends State<GuideHomePage> {
  final GuideViewModel _viewModel = GuideViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'PaintGuide',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'De imagen a pintura acrílica en pasos simples.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        if (_viewModel.errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _viewModel.errorMessage!,
                              style: TextStyle(color: Colors.red.shade800),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        _buildUploadSection(),
                        if (_viewModel.guideResult != null) ...[
                          const SizedBox(height: 48),
                          _buildResultsSection(_viewModel.guideResult!),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              // Loading overlay — Positioned.fill first so it fills the Stack,
              // then AbsorbPointer to block all interaction beneath it.
              if (_viewModel.isProcessing)
                Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: _LoadingOverlay(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _viewModel.isProcessing ? null : _viewModel.pickAndProcessImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: BoxConstraints(
          minHeight: 200,
          maxHeight: _viewModel.guideResult != null ? 350 : 600,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.blueGrey.shade100,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildUploadContent(),
      ),
    );
  }

  Widget _buildUploadContent() {
    // Note: The loading state is now handled by the fullscreen stack overlay.
    // If we are processing, we just show the image behind the blur.

    if (_viewModel.selectedImageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _viewModel.selectedImageBytes!,
            fit: BoxFit.contain,
          ),
          // Only show the change-image overlay when NOT processing
          if (!_viewModel.isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Text(
                    'Cambiar imagen',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          size: 64,
          color: Colors.blueGrey.shade200,
        ),
        const SizedBox(height: 24),
        const Text(
          'Selecciona una imagen',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'JPG o PNG • Max 10MB',
          style: TextStyle(
            color: Colors.black45,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection(GuideResult guide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu Paleta',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: guide.colors.map((c) {
            Color color = Color.fromRGBO(c.r, c.g, c.b, 1.0);
            return _buildColorSwatch(c.hexColor, color, c.role ?? 'color');
          }).toList(),
        ),
        const SizedBox(height: 48),
        const Text(
          'Estrategia Paso a Paso',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        ...guide.steps.asMap().entries.map((entry) {
          int index = entry.key + 1;
          PaintingStep step = entry.value;
          
          Uint8List? stepImage;
          if (guide.stepImages.isNotEmpty && guide.stepImages.length > entry.key) {
            stepImage = guide.stepImages[entry.key];
          }
          
          return _buildStepCard(index, step.title, step.description, stepImage);
        }),
      ],
    );
  }

  Widget _buildColorSwatch(String hex, Color color, String role) {
    // Determine text color based on background luminance for visibility
    double luminance = color.computeLuminance();
    Color textColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            hex,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            role,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int stepNumber, String title, String description, Uint8List? imageBytes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (imageBytes != null) ...[
             const SizedBox(height: 20),
             GestureDetector(
               onTap: () => _showFullscreenImage(context, imageBytes, title),
               child: Center(
                 child: Stack(
                   alignment: Alignment.bottomCenter,
                   children: [
                     Container(
                        constraints: const BoxConstraints(
                          maxHeight: 250,
                          maxWidth: 400,
                        ),
                        decoration: BoxDecoration(
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.blueGrey.shade50, width: 2),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.black.withOpacity(0.02),
                               blurRadius: 8,
                               offset: const Offset(0, 4),                     
                             ),
                           ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                     ),
                     Positioned(
                       bottom: 8,
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.black.withOpacity(0.55),
                           borderRadius: BorderRadius.circular(20),
                         ),
                         child: const Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                             SizedBox(width: 4),
                             Text(
                               'Toca para ver',
                               style: TextStyle(
                                 color: Colors.white,
                                 fontSize: 12,
                                 fontWeight: FontWeight.w500,
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ),
          ]
        ],
      ),
    );
  }

  void _showFullscreenImage(BuildContext context, Uint8List imageBytes, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 6.0,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading Overlay ───────────────────────────────────────────────────────
class _LoadingOverlay extends StatefulWidget {
  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<_LoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _dotsCtrl;
  late final AnimationController _fadeCtrl;

  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Fade-in on mount
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Pulsing ring
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Bouncing dots
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotsCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withOpacity(0.35),
          child: Center(
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 260,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated spinner ring
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        backgroundColor: Colors.blueGrey.shade100,
                        color: Colors.black87,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Procesando',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Animated bouncing dots
                    AnimatedBuilder(
                      animation: _dotsCtrl,
                      builder: (context, _) {
                        final t = _dotsCtrl.value;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) {
                            // stagger each dot by 0.2
                            final phase = ((t - i * 0.25) % 1.0).clamp(0.0, 1.0);
                            final offset = -6.0 * (1.0 - (phase * 2 - 1).abs());
                            return Transform.translate(
                              offset: Offset(0, offset),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Extrayendo colores y\ncalculando estructura.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
