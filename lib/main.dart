import 'dart:typed_data';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/guide_view_model.dart';
import 'core/guide_generator.dart';
import 'core/app_strings.dart';
import 'core/gif_encoder_isolate.dart';

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
  final ValueNotifier<AppLang> _lang = ValueNotifier(AppLang.en);
  final ValueNotifier<bool> _cumulativeMode = ValueNotifier(false);
  final ValueNotifier<bool> _encodingGif   = ValueNotifier(false);

  @override
  void dispose() {
    _viewModel.dispose();
    _lang.dispose();
    _cumulativeMode.dispose();
    _encodingGif.dispose();
    super.dispose();
  }

  Future<void> _downloadGif(GuideResult guide) async {
    if (_encodingGif.value) return;
    _encodingGif.value = true;
    try {
      final images = _cumulativeMode.value
          ? guide.cumulativeStepImages
          : guide.stepImages;
      if (images.isEmpty) return;

      final gifBytes = await compute(encodeAnimatedGif, images);

      // Trigger browser download
      if (kIsWeb && gifBytes.isNotEmpty) {
        final blob = html.Blob([gifBytes], 'image/gif');
        final url  = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'rossidifier_paint_guide.gif')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } finally {
      _encodingGif.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: _lang,
      builder: (context, lang, _) {
        final s = AppStrings(lang);
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
                            // ── Language toggle ──────────────────────────
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => _lang.value =
                                    _lang.value == AppLang.en ? AppLang.es : AppLang.en,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🌐', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Text(
                                        lang == AppLang.en ? 'EN' : 'ES',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // ── Title ───────────────────────────────────
                            Text(
                              s.appTitle,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                letterSpacing: -1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.appSubtitle,
                              style: const TextStyle(
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
                            _buildUploadSection(s),
                            const SizedBox(height: 24),
                            _buildDemoRow(s),
                            if (_viewModel.guideResult != null) ...[
                              const SizedBox(height: 48),
                              _buildResultsSection(_viewModel.guideResult!, s),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Loading overlay
                  if (_viewModel.isProcessing)
                    Positioned.fill(
                      child: AbsorbPointer(
                        absorbing: true,
                        child: _LoadingOverlay(s: s),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUploadSection(AppStrings s) {
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
        child: _buildUploadContent(s),
      ),
    );
  }

  Widget _buildUploadContent(AppStrings s) {
    if (_viewModel.selectedImageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _viewModel.selectedImageBytes!,
            fit: BoxFit.contain,
          ),
          if (!_viewModel.isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Text(
                    s.changeImage,
                    style: const TextStyle(
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
        Text(
          s.uploadPrompt,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.uploadHint,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  static const _demos = [
    (
      label: 'Figura anime',
      emoji: '🗡️',
      url: 'https://images.unsplash.com/photo-1531259683007-016a7b628fc3?w=800',
    ),
    (
      label: 'Ángel de la Independencia',
      emoji: '🏛️',
      url: 'https://images.unsplash.com/photo-1585464231875-d9ef1f5ad396?w=800',
    ),
    (
      label: 'Seattle al amanecer',
      emoji: '🌆',
      url: 'https://images.unsplash.com/photo-1502175353174-a7a70e73b362?w=800',
    ),
  ];

  Widget _buildDemoRow(AppStrings s) {
    final labels = [s.demoAnime, s.demoMexico, s.demoSeattle];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.demoLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black45,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _demos.asMap().entries.map((e) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _buildDemoCard(labels[e.key], e.value.emoji, e.value.url),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildDemoCard(String label, String emoji, String url) {
    final bool disabled = _viewModel.isProcessing;
    return GestureDetector(
      onTap: disabled ? null : () => _viewModel.processImageFromUrl(url),
      child: AnimatedOpacity(
        opacity: disabled ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueGrey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(GuideResult guide, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.paletteTitle,
          style: const TextStyle(
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
        // ── Strategy header + mode toggle + download ────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              s.guideTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Mode toggle pill ──
                ValueListenableBuilder<bool>(
                  valueListenable: _cumulativeMode,
                  builder: (context, cumulative, _) {
                    return GestureDetector(
                      onTap: () => _cumulativeMode.value = !_cumulativeMode.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _renderModePill(label: s.modeSnapshot,    active: !cumulative),
                            _renderModePill(label: s.modeCumulative,  active: cumulative),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                // ── Download GIF button ──
                ValueListenableBuilder<bool>(
                  valueListenable: _encodingGif,
                  builder: (context, encoding, _) {
                    return GestureDetector(
                      onTap: encoding ? null : () => _downloadGif(guide),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: encoding ? Colors.blueGrey.shade100 : Colors.deepPurple.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (encoding)
                              const SizedBox(
                                width: 13, height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.deepPurple,
                                ),
                              )
                            else
                              const Text('⬇', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              encoding ? s.gifEncoding : s.gifDownload,
                              style: TextStyle(
                                color: encoding ? Colors.blueGrey.shade400 : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: _cumulativeMode,
          builder: (context, cumulative, _) => Text(
            cumulative ? s.modeDescCumulative : s.modeDescSnapshot,
            style: const TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ),
        const SizedBox(height: 24),
        // ── Step cards ─────────────────────────────────
        ValueListenableBuilder<bool>(
          valueListenable: _cumulativeMode,
          builder: (context, cumulative, _) {
            final images = cumulative
                ? guide.cumulativeStepImages
                : guide.stepImages;
            return Column(
              children: guide.steps.asMap().entries.map((entry) {
                int index = entry.key + 1;
                PaintingStep step = entry.value;
                Uint8List? stepImage;
                if (images.isNotEmpty && images.length > entry.key) {
                  stepImage = images[entry.key];
                }
                return _buildStepCard(
                  index,
                  s.stepTitle(step.stepKey),
                  s.stepDesc(step.stepKey,
                    lightDir: step.lightDir != null ? s.lightDirLabel(step.lightDir!) : null,
                    lightOpp: step.lightOpp != null ? s.lightDirLabel(step.lightOpp!) : null,
                  ),
                  stepImage,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _renderModePill({required String label, required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.black87 : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.black45,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
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
  final AppStrings s;
  const _LoadingOverlay({required this.s});
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
                    Text(
                      widget.s.loadingTitle,
                      style: const TextStyle(
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
                    Text(
                      widget.s.loadingSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
