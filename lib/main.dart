
import 'dart:math' as math;
import 'package:codeglyphs/src/codeglyph_view.dart';
import 'package:codeglyphs/src/theme.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'core/guide_view_model.dart';
import 'core/guide_generator.dart';
import 'core/pdf_generator.dart';
import 'core/painting_utils.dart';
import 'core/app_strings.dart';
import 'core/gif_encoder_isolate.dart';

import 'package:sandblaster/theme/liquid_glass_theme.dart';
import 'package:sandblaster/widgets/animated_background.dart';
import 'package:sandblaster/components/glass_toggle_chip.dart';
import 'package:sandblaster/components/glass_card.dart';
import 'package:sandblaster/components/glass_button.dart';
import 'package:sandblaster/widgets/liquid_glass_container.dart';
import 'package:codeglyphs/src/codeglyph_view.dart';
import 'package:codeglyphs/src/theme.dart';

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
      theme: LiquidGlassTheme.inkyTheme,
      home: const GuideHomePage(),
    );
  }
}

enum AppTab { guide, about }
enum ResultTab { snapshot, cumulative }

class GuideHomePage extends StatefulWidget {
  const GuideHomePage({super.key});

  @override
  State<GuideHomePage> createState() => _GuideHomePageState();
}

class _GuideHomePageState extends State<GuideHomePage> {
  final GuideViewModel _viewModel = GuideViewModel();
  final ValueNotifier<AppLang> _lang = ValueNotifier(AppLang.en);
  final ValueNotifier<AppTab> _selectedAppTab = ValueNotifier(AppTab.guide);
  final ValueNotifier<ResultTab> _selectedResultTab = ValueNotifier(ResultTab.cumulative);
  final ValueNotifier<bool> _encodingGif   = ValueNotifier(false);

  @override
  void dispose() {
    _viewModel.dispose();
    _lang.dispose();
    _selectedAppTab.dispose();
    _selectedResultTab.dispose();
    _encodingGif.dispose();
    super.dispose();
  }

  Future<void> _downloadGif(GuideResult guide) async {
    if (_encodingGif.value) return;
    _encodingGif.value = true;
    try {
      final images = _selectedResultTab.value == ResultTab.cumulative
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
            final isMobile = MediaQuery.of(context).size.width < 750;

            return Scaffold(
              backgroundColor: context.sbTheme.bgDeep,
              body: AnimatedBackground(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SafeArea(
                        bottom: true, // Crucial for mobile browser bars
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 24, 
                            vertical: isMobile ? 16 : 32
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ── Header ──────────────────────────────────────────────
                              if (isMobile)
                                Column(
                                  children: [
                                    Text(
                                      s.appTitle,
                                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        color: context.sbTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      s.appSubtitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: context.sbTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ValueListenableBuilder<AppTab>(
                                      valueListenable: _selectedAppTab,
                                      builder: (context, currentTab, _) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMd),
                                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildAppTab(AppTab.guide, lang == AppLang.en ? 'Rossifier: What r we painting today' : 'Rossifier: ¿Qué pintamos hoy?', Icons.format_paint_rounded, currentTab == AppTab.guide),
                                              _buildAppTab(AppTab.about, s.tabMath, Icons.functions_rounded, currentTab == AppTab.about),
                                            ],
                                          ),
                                        );
                                      }
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('EN', style: TextStyle(color: context.sbTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(width: 8),
                                        GlassToggle(
                                          value: lang == AppLang.es,
                                          activeTrackColor: context.sbTheme.orbEmerald,
                                          activeThumbIcon: const Icon(Icons.language, size: 12, color: Colors.black),
                                          inactiveThumbIcon: const Icon(Icons.language, size: 12, color: Colors.white),
                                          onChanged: (isEs) => _lang.value = isEs ? AppLang.es : AppLang.en,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('ES', style: TextStyle(color: context.sbTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.appTitle,
                                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                              color: context.sbTheme.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            s.appSubtitle,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: context.sbTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Top-Right Global Tabs
                                  ValueListenableBuilder<AppTab>(
                                    valueListenable: _selectedAppTab,
                                    builder: (context, currentTab, _) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMd),
                                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: Row(
                                          children: [
                                            _buildAppTab(AppTab.guide, lang == AppLang.en ? 'PaintGuide App' : 'App PaintGuide', Icons.format_paint_rounded, currentTab == AppTab.guide),
                                            _buildAppTab(AppTab.about, s.tabMath, Icons.functions_rounded, currentTab == AppTab.about),
                                          ],
                                        ),
                                      );
                                    }
                                  ),
                                  const SizedBox(width: 24),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('EN', style: TextStyle(color: context.sbTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      GlassToggle(
                                        value: lang == AppLang.es,
                                        activeTrackColor: context.sbTheme.orbEmerald,
                                        activeThumbIcon: const Icon(Icons.language, size: 12, color: Colors.black),
                                        inactiveThumbIcon: const Icon(Icons.language, size: 12, color: Colors.white),
                                        onChanged: (isEs) => _lang.value = isEs ? AppLang.es : AppLang.en,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('ES', style: TextStyle(color: context.sbTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 48),

                              ValueListenableBuilder<AppTab>(
                                valueListenable: _selectedAppTab,
                                builder: (context, appTab, _) {
                                  if (appTab == AppTab.about) {
                                    return Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 800),
                                        child: _buildMathExplanation(s),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      if (_viewModel.errorMessage != null)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 24),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            _viewModel.errorMessage!,
                                            style: TextStyle(color: Colors.red.shade200),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      
                                      // Always show upload section if we have an image or are not results-loaded
                                      Center(child: _buildUploadSection(s)),
                                      
                                      if (_viewModel.guideResult == null && !_viewModel.isProcessing) ...[
                                        const SizedBox(height: 24),
                                        _buildDemoRow(s),
                                      ],
                                      
                                      if (_viewModel.guideResult != null) ...[
                                        const SizedBox(height: 48),
                                        _buildResultsSection(_viewModel.guideResult!, s),
                                      ],
                                      
                                      // If processing but no guide yet, show the demo row or a spacer to prevent layout jumping
                                      if (_viewModel.isProcessing && _viewModel.guideResult == null)
                                        const SizedBox(height: 200),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 80),
                              // ── Footer ───────────────────────────────────────────
                              Column(
                                children: [
                                  Text(
                                    'Built with ❤️ by Rodo 2026',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: context.sbTheme.textSecondary,
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
                                          color: context.sbTheme.accent,
                                          decoration: TextDecoration.underline,
                                          decorationColor: context.sbTheme.accent,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 100), // Extra space to scroll past mobile navigation bars
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
    final bool hasImage = _viewModel.selectedImageBytes != null;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(
        maxWidth: 600,
        minHeight: 200,
        maxHeight: 350,
      ),
      child: LiquidGlassContainer(
        onTap: (hasImage || _viewModel.isProcessing) ? null : _viewModel.pickAndProcessImage,
        padding: EdgeInsets.zero,
        borderRadius: LiquidGlassTheme.radiusLg,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusLg),
          child: _buildUploadContent(s, context),
        ),
      ),
    );

    if (hasImage && !_viewModel.isProcessing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: 16),
          GlassButton(
            label: s.changeImage,
            icon: Icons.replay_rounded,
            onPressed: () => _confirmAndChangeImage(s),
          ),
        ],
      );
    }

    return content;
  }

  void _confirmAndChangeImage(AppStrings s) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: LiquidGlassContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: LiquidGlassTheme.radiusLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange.shade300),
                  const SizedBox(height: 16),
                  Text(
                    s.confirmChangeTitle,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      color: ctx.sbTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.confirmChangeDesc,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: ctx.sbTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GlassButton(
                        label: s.confirmCancel,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      const SizedBox(width: 12),
                      GlassButton(
                        label: s.confirmYes,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _viewModel.pickAndProcessImage();
                        },
                        accentColor: Colors.deepOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadContent(AppStrings s, BuildContext context) {
    if (_viewModel.selectedImageBytes != null) {
      return Image.memory(
        _viewModel.selectedImageBytes!,
        fit: BoxFit.contain,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 64,
          color: context.sbTheme.accent,
        ),
        const SizedBox(height: 24),
        Text(
          s.uploadPrompt,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: context.sbTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          s.uploadHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.sbTheme.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) => Column(
            children: [
              Text(
                '🎨 Detail Level: ${_viewModel.complexity} Colors',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.sbTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(
                width: 250,
                child: CupertinoSlider(
                  value: _viewModel.complexity.toDouble(),
                  min: 3,
                  max: 10,
                  divisions: 7,
                  activeColor: context.sbTheme.orbCyan,
                  thumbColor: Colors.white,
                  onChanged: (val) {
                    _viewModel.setComplexity(val.toInt());
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
            color: context.sbTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
      Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _demos.asMap().entries.map((e) => SizedBox(
            width: 140, // Fixed width to ensure nice grid behavior on Wrap
            child: _buildDemoCard(labels[e.key], e.value.emoji, e.value.url),
          )).toList(),
        ),
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
                      color: context.sbTheme.textSecondary,
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
            color: context.sbTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: guide.colors.asMap().entries.map((entry) {
            final int index = entry.key;
            final c = entry.value;
            Color color = Color.fromRGBO(c.r, c.g, c.b, 1.0);
            return _buildColorSwatch(c.hexColor, color, c.role ?? 'color', index);
          }).toList(),
        ),
        const SizedBox(height: 48),
        // ── Strategy header ────────
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            Text(
              s.guideTitle,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: context.sbTheme.textPrimary,
              ),
            ),
            ValueListenableBuilder<ResultTab>(
              valueListenable: _selectedResultTab,
              builder: (context, tab, _) => _buildResultTabSelector(s, tab),
            ),
          ]
        ),
        const SizedBox(height: 24),
        // ── Tab Content ─────────────────────────────────
        ValueListenableBuilder<ResultTab>(
          valueListenable: _selectedResultTab,
          builder: (context, tab, _) {
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
                      color: context.sbTheme.textTertiary,
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
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        GlassButton(
                          label: encoding ? s.gifEncoding : s.gifDownload,
                          icon: encoding ? null : Icons.download_rounded,
                          loading: encoding,
                          onPressed: encoding ? null : () => _downloadGif(guide),
                          accentColor: context.sbTheme.orbCyan,
                        ),
                        GlassButton(
                          label: 'Export PDF',
                          icon: Icons.picture_as_pdf_rounded,
                          onPressed: () => PdfGenerator.exportGuide(guide, s),
                          accentColor: context.sbTheme.orbPink,
                        ),
                      ],
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

  Widget _buildAppTab(AppTab tab, String label, IconData icon, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _selectedAppTab.value = tab,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? context.sbTheme.glassSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusSm),
            border: Border.all(
              color: isActive ? context.sbTheme.glassBorder : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isActive ? context.sbTheme.textPrimary : context.sbTheme.textTertiary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isActive ? context.sbTheme.textPrimary : context.sbTheme.textTertiary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTab(ResultTab tab, String label, IconData icon, bool isActive) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _selectedResultTab.value = tab,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? context.sbTheme.glassSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusSm),
            border: Border.all(
              color: isActive ? context.sbTheme.glassBorder : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isActive ? context.sbTheme.textPrimary : context.sbTheme.textTertiary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isActive ? context.sbTheme.textPrimary : context.sbTheme.textTertiary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTabSelector(AppStrings s, ResultTab activeTab) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMd),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildResultTab(ResultTab.snapshot, s.tabSnapshot, Icons.layers_clear_rounded, activeTab == ResultTab.snapshot),
          _buildResultTab(ResultTab.cumulative, s.tabCumulative, Icons.layers_rounded, activeTab == ResultTab.cumulative),
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
          Text(s.mathIntroTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: context.sbTheme.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(s.mathIntroDesc, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.sbTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 32),
          _buildMathStep(s.mathStep1Title, s.mathStep1Desc, Icons.color_lens_rounded, codeSnippet: _kMeansSnippet),
          _buildMathStep(s.mathStep2Title, s.mathStep2Desc, Icons.architecture_rounded, codeSnippet: _sobelSnippet),
          _buildMathStep(s.mathStep3Title, s.mathStep3Desc, Icons.blur_on_rounded, codeSnippet: _microContrastSnippet),
        ],
      ),
    );
  }

  Widget _buildMathStep(String title, String desc, IconData icon, {String? codeSnippet}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.sbTheme.glassSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.sbTheme.glassBorder),
                ),
                child: Icon(icon, color: context.sbTheme.orbCyan, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.sbTheme.textPrimary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(desc, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.sbTheme.textTertiary, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          if (codeSnippet != null) ...[
            const SizedBox(height: 16),
            CodeglyphView(
              code: codeSnippet,
              language: 'dart',
              theme: CodeglyphTheme.voidCentury,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorSwatch(String hex, Color color, String role, int index) {
    // Determine text color based on background luminance for visibility
    double luminance = color.computeLuminance();
    Color textColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showColorPickerOptions(context, index, color),
        child: Container(
          width: 130, // Wider for text
          height: 110, // Taller for text
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
          const SizedBox(height: 2),
          Text(
            PaintingUtils.getPaintMix(color),
            style: TextStyle(
              color: textColor.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            role,
            style: TextStyle(
              color: textColor.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _showColorPickerOptions(BuildContext context, int index, Color currentColor) {
    Color selectedColor = currentColor;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: context.sbTheme.bgSurface,
          title: Text('Edit Paint Color', style: TextStyle(color: context.sbTheme.textPrimary)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                selectedColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: context.sbTheme.textSecondary)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            GlassButton(
              label: 'Apply Mix',
              accentColor: context.sbTheme.orbCyan,
              onPressed: () {
                Navigator.of(ctx).pop();
                _viewModel.overrideColor(index, selectedColor);
              },
            ),
          ],
        );
      },
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
        contentMaxWidth: 700,
        contentAlignment: Alignment.topCenter,
        child: imageBytes != null
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _showFullscreenGallery(
                        context, galleryImages, galleryTitles, galleryStartIndex),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        constraints: const BoxConstraints(
                          maxHeight: 350,
                          maxWidth: 500, // Hard limit to prevent massive stretching
                        ),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
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
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: Image.memory(
                                  imageBytes,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              child: GlassChip(
                                label: 'Pinch to zoom • Tap for gallery', 
                                icon: Icons.zoom_in_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 6.0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                      maxHeight: constraints.maxHeight,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        widget.images[index], 
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
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
          color: Colors.black.withOpacity(0.8),
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
            child: LiquidGlassContainer(
              width: 280,
              borderRadius: LiquidGlassTheme.radiusLg,
              padding: const EdgeInsets.all(32),
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
                    backgroundColor: context.sbTheme.glassBorder,
                    color: context.sbTheme.orbCyan,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.s.loadingTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.sbTheme.textPrimary,
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
                                  color: context.sbTheme.orbCyan.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.sbTheme.orbCyan.withOpacity(0.5),
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
                        color: context.sbTheme.textTertiary,
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



const String _kMeansSnippet = '''
// K-Means Iteration Logic
while (changed && iteration < maxIterations) {
  changed = false;
  iteration++;

  for (int i = 0; i < pixels.length; i++) {
    int bestCluster = 0;
    double minDistance = double.infinity;
    for (int j = 0; j < k; j++) {
      double dist = _distance(pixels[i], centroids[j]);
      if (dist < minDistance) {
        minDistance = dist;
        bestCluster = j;
      }
    }
    if (assignments[i] != bestCluster) {
      assignments[i] = bestCluster;
      changed = true;
    }
  }
}
''';

const String _sobelSnippet = '''
// 1. Medium blur to remove micro-details before Sobel
img.Image blurredForEdges = img.gaussianBlur(baseImage.clone(), radius: 2);

// 2. Deep edge detection
img.Image edges = img.sobel(blurredForEdges);
var shadowColor = globalColors.length > 2 ? globalColors[2] : globalColors[0];

// 3. Intermediate threshold and blend
for (int y = 0; y < baseImage.height; y++) {
  for (int x = 0; x < baseImage.width; x++) {
     var ep = edges.getPixel(x, y);
     num mag = ep.r; 
     
     // Thresholding: If it's a clear edge but not noise (mag > 45)
     if (mag > 45 && mag < 200) {
         var sp = stepImg.getPixel(x, y);
         // Blend with low opacity (alpha 0.45) using shadow color
         sp.r = (sp.r * 0.55 + shadowColor.r * 0.45).floor();
         sp.g = (sp.g * 0.55 + shadowColor.g * 0.45).floor();
         sp.b = (sp.b * 0.55 + shadowColor.b * 0.45).floor();
     }
  }
}
''';

const String _microContrastSnippet = '''
// High-Frequency Micro-Contrast Isolation
// 1. Heavy blur to separate frequencies
img.Image blurred = img.gaussianBlur(baseImage.clone(), radius: 4);

// 2. Calculate continuous high-pass 
for (int y = 0; y < baseImage.height; y++) {
  for (int x = 0; x < baseImage.width; x++) {
    final orig = baseImage.getPixel(x, y);
    final blur = blurred.getPixel(x, y);

    int rDiff = max(0, (orig.r - blur.r).toInt());
    int gDiff = max(0, (orig.g - blur.g).toInt());
    int bDiff = max(0, (orig.b - blur.b).toInt());

    double magnitude = sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff);
    
    // Apply branch if frequency threshold is surpassed
    if (magnitude > threshold) {
      sp.r = min(255, (orig.r + (rDiff * gain)).toInt());
      sp.g = min(255, (orig.g + (gDiff * gain)).toInt());
      sp.b = min(255, (orig.b + (bDiff * gain)).toInt());
    }
  }
}
''';
