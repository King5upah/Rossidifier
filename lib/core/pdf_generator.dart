import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart' as material;
import 'color_extractor.dart';
import 'guide_generator.dart';
import 'painting_utils.dart';
import 'app_strings.dart';

class PdfGenerator {
  static Future<void> exportGuide(GuideResult guide, AppStrings strings) async {
    final pdf = pw.Document();

    final customFont = await PdfGoogleFonts.interRegular();
    final customFontBold = await PdfGoogleFonts.interBold();

    final theme = pw.ThemeData.withFont(
      base: customFont,
      bold: customFontBold,
    );

    // Page 1: Palette & Mixing Guide
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(strings.appTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Pro-Painter Guide', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Color Palette & Physical Mixing Formulas', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Use these formulas to mix your actual acrylic or oil paints.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 20),
              pw.Wrap(
                spacing: 20,
                runSpacing: 20,
                children: guide.colors.map((c) {
                  final colorVal = material.Color.fromRGBO(c.r, c.g, c.b, 1.0);
                  final mixFormula = PaintingUtils.getPaintMix(colorVal);

                  return pw.Container(
                    width: 160,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt((0xFF000000 | (c.r << 16) | (c.g << 8) | c.b)),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(c.hexColor, style: pw.TextStyle(color: _getTextColor(c), fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(c.role?.toUpperCase() ?? 'COLOR', style: pw.TextStyle(color: _getTextColor(c), fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xCCFFFFFF),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            mixFormula,
                            style: pw.TextStyle(color: PdfColors.black, fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 40),
              pw.Text('Painting Strategy', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...guide.steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Bullet(
                    text: '${strings.stepTitle(step.stepKey)}: ${strings.stepDesc(step.stepKey,
                      lightDir: step.lightDir != null ? strings.lightDirLabel(step.lightDir!) : null,
                      lightOpp: step.lightOpp != null ? strings.lightDirLabel(step.lightOpp!) : null,
                    )}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    // Remaining Pages: Step by Step Images
    for (int i = 0; i < guide.steps.length; i++) {
        if (guide.stepImages.isEmpty || i >= guide.stepImages.length) break;

        final step = guide.steps[i];
        final title = strings.stepTitle(step.stepKey);
        final desc = strings.stepDesc(
            step.stepKey,
            lightDir: step.lightDir != null ? strings.lightDirLabel(step.lightDir!) : null,
            lightOpp: step.lightOpp != null ? strings.lightDirLabel(step.lightOpp!) : null,
        );

        final image = pw.MemoryImage(guide.stepImages[i]);

        pdf.addPage(
            pw.Page(
                pageFormat: PdfPageFormat.a4,
                theme: theme,
                build: (pw.Context context) {
                    return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                            pw.Header(
                                level: 1,
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Step ${i + 1}: $title', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                                    pw.Text(strings.appTitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                                  ],
                                ),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text(desc, style: const pw.TextStyle(fontSize: 12)),
                            pw.SizedBox(height: 20),
                            pw.Expanded(
                                child: pw.Center(
                                    child: pw.Image(image, fit: pw.BoxFit.contain),
                                ),
                            ),
                            pw.SizedBox(height: 20),
                            pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text('Page ${i + 2}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                            ),
                        ],
                    );
                },
            ),
        );
    }

    try {
      // Use layoutPdf for much better mobile web support (triggers native print/save dialog)
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Rossidifier_Guide.pdf',
      );
    } catch (e) {
      material.debugPrint('Error exporting PDF: $e');
    }
  }

  static PdfColor _getTextColor(ColorCluster c) {
    // Luminance approximation for text visibility
    double lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return lum > 128 ? PdfColors.black : PdfColors.white;
  }
}
