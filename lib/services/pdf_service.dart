import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../services/logger_service.dart'; // Import your logger

class PdfService {
  /// Generates a professional PDF report including insurance profile details,
  /// a summary table, a photo appendix, and high-value detail pages.
  static Future<void> generateInventoryReport(List<Item> items, SettingsProvider settings) async {
    logger.log("PDF: Starting report generation for ${items.length} items...");

    try {
      final pdf = pw.Document();
      final NumberFormat currencyFormat = NumberFormat.simpleCurrency();
      final DateTime now = DateTime.now();

      // 1. Calculate Summary Data
      double totalValue = items.fold(0, (sum, item) => sum + item.value);
      logger.log("PDF: Calculated total value: ${currencyFormat.format(totalValue)}");

      // --- PAGE 1: PROFESSIONAL COVER & SUMMARY TABLE ---
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Personalized Insurance Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      settings.userName.isEmpty ? "HOME INVENTORY REPORT" : settings.userName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    if (settings.address.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(settings.address, style: const pw.TextStyle(fontSize: 10)),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "INSURER: ${settings.insuranceCompany.isEmpty ? 'NOT SPECIFIED' : settings.insuranceCompany.toUpperCase()}",
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      "POLICY #: ${settings.policyNumber.isEmpty ? 'N/A' : settings.policyNumber}",
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Generated on: ${DateFormat.yMMMMd().format(now)}",
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text("TOTAL ESTIMATED VALUE", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                        currencyFormat.format(totalValue),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 10),

            pw.Text("Inventory Overview", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Summary Table
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              cellHeight: 25,
              columnWidths: {
                0: const pw.FlexColumnWidth(3), // Name
                1: const pw.FlexColumnWidth(2), // Location
                2: const pw.FlexColumnWidth(2), // Date
                3: const pw.FlexColumnWidth(2), // Value
              },
              headers: ['Item Name', 'Location', 'Purchase Date', 'Value'],
              data: items.map((item) => [
                item.name,
                "${item.room ?? 'N/A'}\n(${item.category ?? 'N/A'})",
                DateFormat.yMMMd().format(item.purchaseDate),
                currencyFormat.format(item.value),
              ]).toList(),
            ),
          ],
        ),
      );
      logger.log("PDF: Cover page and summary table generated.");

      // --- APPENDIX: PHOTO EVIDENCE GRID ---
      logger.log("PDF: Processing image appendix...");
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(level: 0, text: "Photo Evidence Appendix"),
            pw.SizedBox(height: 10),
            pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              children: items.map((item) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: item.imagePaths.isNotEmpty
                            ? _buildPdfImage(item.imagePaths[0], item.name)
                            : pw.Container(color: PdfColors.grey300),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(
                        "${item.room ?? 'General'} | ${currencyFormat.format(item.value)}",
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );

      // --- HIGH VALUE DETAIL PAGES ---
      final highValueItems = items.where((i) => i.value >= 1000).toList();
      if (highValueItems.isNotEmpty) {
        logger.log("PDF: Generating ${highValueItems.length} high-value detail pages.");
        for (var item in highValueItems) {
          pdf.addPage(
            pw.Page(
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(level: 0, text: "High Value Asset: ${item.name}"),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _detailRow("Value", currencyFormat.format(item.value)),
                            _detailRow("Brand", item.brand ?? "N/A"),
                            _detailRow("Model", item.model ?? "N/A"),
                            _detailRow("Serial #", item.serialNumber ?? "N/A"),
                            _detailRow("Purchase Date", DateFormat.yMMMMd().format(item.purchaseDate)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        flex: 1,
                        child: item.imagePaths.isNotEmpty
                            ? _buildPdfImage(item.imagePaths[0], "Detail: ${item.name}")
                            : pw.Container(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      }

      logger.log("PDF: Document complete. Sending to OS print spooler...");
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      logger.log("PDF: Printing/Saving UI closed.");

    } catch (e) {
      logger.log("CRITICAL PDF ERROR", error: e);
      rethrow;
    }
  }

  /// Helper to handle image reading with logging
  static pw.Widget _buildPdfImage(String imagePath, String itemName) {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return pw.Image(
          pw.MemoryImage(file.readAsBytesSync()),
          fit: pw.BoxFit.cover,
        );
      } else {
        logger.log("PDF Warning: Image file missing for $itemName at $imagePath");
        return pw.Container(color: PdfColors.grey300);
      }
    } catch (e) {
      logger.log("PDF Error: Failed to process image for $itemName", error: e);
      return pw.Container(color: PdfColors.red100);
    }
  }

  static pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: "$label: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}