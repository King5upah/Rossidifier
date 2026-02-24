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

import 'package:sandblaster/theme/liquid_glass_theme.dart';
import 'package:sandblaster/widgets/animated_background.dart';
import 'package:sandblaster/components/glass_toggle_chip.dart';
import 'package:sandblaster/components/glass_card.dart';
import 'package:sandblaster/components/glass_button.dart';
import 'package:sandblaster/widgets/liquid_glass_container.dart';

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
      theme: LiquidGlassTheme.themeData,
      home: const GuideHomePage(),
    );
  }
}

enum ResultTab { snapshot, cumulative, math }

class GuideHomePage extends StatefulWidget {
  const GuideHomePage({super.key});

  @override
  State<GuideHomePage> createState() => _GuideHomePageState();
}

class _GuideHomePageState extends State<GuideHomePage> {
  final GuideViewModel _viewModel = GuideViewModel();
  final ValueNotifier<AppLang> _lang = ValueNotifier(AppLang.en);
  final ValueNotifier<ResultTab> _selectedTab = ValueNotifier(ResultTab.cumulative);
  final ValueNotifier<bool> _encodingGif   = ValueNotifier(false);

  @override
  void dispose() {
    _viewModel.dispose();
    _lang.dispose();
    _selectedTab.dispose();
    _encodingGif.dispose();
    super.dispose();
  }

  Future<void> _downloadGif(GuideResult guide) async {
    if (_encodingGif.value) return;
    _encodingGif.value = true;
    try {
      final images = _selectedTab.value == ResultTab.cumulative
          ? guide.cumulativeStepImages
          : guide.stepImages;
      if (images.isEmpty) return;

      final gifBytes = await encodeAnimatedGif(images);

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
              backgroundColor: LiquidGlassTheme.bgDeep,
              body: AnimatedBackground(
                child: Stack(
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('EN', style: TextStyle(color: LiquidGlassTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  GlassToggle(
                                    value: lang == AppLang.es,
                                    onChanged: (isEs) => _lang.value = isEs ? AppLang.es : AppLang.en,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('ES', style: TextStyle(color: LiquidGlassTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // ── Title ───────────────────────────────────
                            Text(
                              s.appTitle,
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: LiquidGlassTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.appSubtitle,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: LiquidGlassTheme.textSecondary,
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
                            Center(child: _buildUploadSection(s)),
                            const SizedBox(height: 24),
                            _buildDemoRow(s),
                              if (_viewModel.guideResult != null) ...[
                                const SizedBox(height: 48),
                                _buildResultsSection(_viewModel.guideResult!, s),
                              ],
                              const SizedBox(height: 80),
                              // ── Footer ───────────────────────────────────────────
                              Column(
                                children: [
                                  Text(
                                    'Built with ❤️ by Rodo 2026',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: LiquidGlassTheme.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => html.window.open('https://github.com/King5upah/SandBlasterUI', '_blank'),
                                      child: Text(
                                        'Blasted with Sand',
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: LiquidGlassTheme.accent,
                                          decoration: TextDecoration.underline,
                                          decorationColor: LiquidGlassTheme.accent,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
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
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildUploadSection(AppStrings s) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: BoxConstraints(
        maxWidth: 600,
        minHeight: 200,
        maxHeight: _viewModel.guideResult != null ? 350 : 350,
      ),
      child: LiquidGlassContainer(
        onTap: _viewModel.isProcessing ? null : _viewModel.pickAndProcessImage,
        padding: EdgeInsets.zero,
        borderRadius: LiquidGlassTheme.radiusLg,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusLg),
          child: _buildUploadContent(s, context),
        ),
      ),
    );
  }

  Widget _buildUploadContent(AppStrings s, BuildContext context) {
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
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: GlassChip(
                    label: s.changeImage,
                    icon: Icons.edit,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        const Icon(
          Icons.cloud_upload_outlined,
          size: 64,
          color: LiquidGlassTheme.accent,
        ),
        const SizedBox(height: 24),
        Text(
          s.uploadPrompt,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: LiquidGlassTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          s.uploadHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: LiquidGlassTheme.textTertiary,
          ),
          textAlign: TextAlign.center,
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
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: LiquidGlassTheme.textSecondary,
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
    return AnimatedOpacity(
      opacity: disabled ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: 72,
        child: LiquidGlassContainer(
          borderRadius: LiquidGlassTheme.radiusSm,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: disabled ? null : () => _viewModel.processImageFromUrl(url),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                Container(
                  height: 24,
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20, height: 1.0),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: LiquidGlassTheme.textSecondary,
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
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: LiquidGlassTheme.textPrimary,
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
        // ── Strategy header ────────
        Text(
          s.guideTitle,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: LiquidGlassTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<ResultTab>(
          valueListenable: _selectedTab,
          builder: (context, tab, _) => _buildTabSelector(s, tab),
        ),
        const SizedBox(height: 24),
        // ── Tab Content ─────────────────────────────────
        ValueListenableBuilder<ResultTab>(
          valueListenable: _selectedTab,
          builder: (context, tab, _) {
            if (tab == ResultTab.math) {
              return _buildMathExplanation(s);
            }

            final isCumulative = tab == ResultTab.cumulative;
            final images = isCumulative
                ? guide.cumulativeStepImages
                : guide.stepImages;
            final titles = guide.steps.map((step) => s.stepTitle(step.stepKey)).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    isCumulative ? s.modeDescCumulative : s.modeDescSnapshot,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LiquidGlassTheme.textTertiary,
                    ),
                  ),
                ),
                ...guide.steps.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  PaintingStep step = entry.value;
                  Uint8List? stepImage;
                  if (images.isNotEmpty && images.length > entry.key) {
                    stepImage = images[entry.key];
                  }
                  return _buildStepCard(
                    index,
                    titles[entry.key],
                    s.stepDesc(step.stepKey,
                      lightDir: step.lightDir != null ? s.lightDirLabel(step.lightDir!) : null,
                      lightOpp: step.lightOpp != null ? s.lightDirLabel(step.lightOpp!) : null,
                    ),
                    stepImage,
                    images,
                    titles,
                    entry.key,
                  );
                }),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: _encodingGif,
                  builder: (context, encoding, _) {
                    return GlassButton(
                      label: encoding ? s.gifEncoding : s.gifDownload,
                      icon: encoding ? null : Icons.download_rounded,
                      loading: encoding,
                      onPressed: encoding ? null : () => _downloadGif(guide),
                      accentColor: LiquidGlassTheme.orbCyan,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTab(ResultTab tab, String label, IconData icon, bool isActive) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _selectedTab.value = tab,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isActive ? LiquidGlassTheme.glassSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusSm),
              border: Border.all(
                color: isActive ? LiquidGlassTheme.glassBorder : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isActive ? LiquidGlassTheme.textPrimary : LiquidGlassTheme.textTertiary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive ? LiquidGlassTheme.textPrimary : LiquidGlassTheme.textTertiary,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(AppStrings s, ResultTab activeTab) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMd),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTab(ResultTab.snapshot, s.tabSnapshot, Icons.layers_clear_rounded, activeTab == ResultTab.snapshot),
          _buildTab(ResultTab.cumulative, s.tabCumulative, Icons.layers_rounded, activeTab == ResultTab.cumulative),
          _buildTab(ResultTab.math, s.tabMath, Icons.functions_rounded, activeTab == ResultTab.math),
        ],
      ),
    );
  }

  Widget _buildMathExplanation(AppStrings s) {
    return LiquidGlassContainer(
      padding: const EdgeInsets.all(32),
      borderRadius: LiquidGlassTheme.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.mathIntroTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: LiquidGlassTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(s.mathIntroDesc, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: LiquidGlassTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 32),
          _buildMathStep(s.mathStep1Title, s.mathStep1Desc, Icons.color_lens_rounded),
          _buildMathStep(s.mathStep2Title, s.mathStep2Desc, Icons.architecture_rounded),
          _buildMathStep(s.mathStep3Title, s.mathStep3Desc, Icons.blur_on_rounded),
        ],
      ),
    );
  }

  Widget _buildMathStep(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LiquidGlassTheme.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: LiquidGlassTheme.glassBorder),
            ),
            child: Icon(icon, color: LiquidGlassTheme.orbCyan, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: LiquidGlassTheme.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(desc, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: LiquidGlassTheme.textTertiary, height: 1.5)),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusLg),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: -5,
            offset: const Offset(0, 8),
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

  Widget _buildStepCard(
    int stepNumber,
    String title,
    String description,
    Uint8List? imageBytes,
    List<Uint8List> galleryImages,
    List<String> galleryTitles,
    int galleryStartIndex,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        title: title,
        subtitle: description,
        leadingIcon: Icons.format_paint_rounded,
        child: imageBytes != null
            ? GestureDetector(
                onTap: () => _showFullscreenGallery(context, galleryImages, galleryTitles, galleryStartIndex),
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
                          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusSm),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
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
                        child: GlassChip(
                          label: 'Tap to view',
                          icon: Icons.zoom_in_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _showFullscreenGallery(BuildContext context, List<Uint8List> images, List<String> titles, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      useSafeArea: true,
      builder: (ctx) => _GalleryDialog(
        images: images,
        titles: titles,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _GalleryDialog extends StatefulWidget {
  final List<Uint8List> images;
  final List<String> titles;
  final int initialIndex;

  const _GalleryDialog({
    required this.images,
    required this.titles,
    required this.initialIndex,
  });

  @override
  State<_GalleryDialog> createState() => _GalleryDialogState();
}

class _GalleryDialogState extends State<_GalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 6.0,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(widget.images[index], fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GlassChip(
                  label: '${_currentIndex + 1}/${widget.images.length} - ${widget.titles.isNotEmpty ? widget.titles[_currentIndex] : ''}',
                  color: Colors.white,
                ),
                GlassButton(
                  variant: GlassButtonVariant.icon,
                  icon: Icons.close_rounded,
                  accentColor: Colors.white,
                  onPressed: () => Navigator.of(context).pop(), // Pass directly, NO GestureDetectors outside
                ),
              ],
            ),
          ),
          // Navigation Chevrons
          Positioned.fill(
            child: Stack(
              children: [
                if (_currentIndex > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassButton(
                      variant: GlassButtonVariant.icon,
                      icon: Icons.chevron_left_rounded,
                      accentColor: Colors.white,
                      onPressed: () {
                        _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                    ),
                  ),
                if (_currentIndex < widget.images.length - 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GlassButton(
                      variant: GlassButtonVariant.icon,
                      icon: Icons.chevron_right_rounded,
                      accentColor: Colors.white,
                      onPressed: () {
                        _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
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
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: ScaleTransition(
              scale: _pulseAnim,
              child: LiquidGlassContainer(
                width: 280,
                borderRadius: LiquidGlassTheme.radiusLg,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    // Animated spinner ring
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        backgroundColor: LiquidGlassTheme.glassBorder,
                        color: LiquidGlassTheme.orbCyan,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      widget.s.loadingTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: LiquidGlassTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: LiquidGlassTheme.orbCyan.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: LiquidGlassTheme.orbCyan.withOpacity(0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LiquidGlassTheme.textTertiary,
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
