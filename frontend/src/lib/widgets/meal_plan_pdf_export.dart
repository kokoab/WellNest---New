import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:wellnest/models/meal_plan.dart';
import 'package:wellnest/services/meal_plan_service.dart';

/// Client-side PDF export for a meal-plan week (matches legacy strip behavior).
abstract final class MealPlanPdfExport {
  static Future<void> shareWeekPdf(DateTime weekStart) async {
    final exportData =
        await MealPlanService.instance.fetchExportData(weekStart);
    final pdfBytes = await _generatePdf(exportData);
    await _saveAndShare(pdfBytes, exportData.weekStart);
  }

  static Future<Uint8List> _generatePdf(MealPlanExport data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'WellNest — Weekly Meal Plan',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${data.weekStart}  to  ${data.weekEnd}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Prepared for ${data.userName}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),
              if (data.meals.isEmpty)
                pw.Text(
                  'No meals planned for this week.',
                  style: const pw.TextStyle(fontSize: 14),
                )
              else
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.green50),
                  cellHeight: 30,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(3),
                    4: const pw.FlexColumnWidth(2),
                  },
                  headers: ['Day', 'Date', 'Slot', 'Recipe', 'Prep Time'],
                  data: data.meals
                      .map(
                        (m) => [
                          m.day,
                          m.date,
                          m.mealSlot,
                          m.recipeTitle,
                          m.prepTime != null ? '${m.prepTime} min' : '—',
                        ],
                      )
                      .toList(),
                ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static Future<void> _saveAndShare(Uint8List bytes, String weekStart) async {
    final fileName = 'meal-plan-$weekStart.pdf';

    if (kIsWeb) {
      await Share.shareXFiles([
        XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
      ]);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)]);
  }
}
