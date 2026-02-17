import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/item.dart';

class PdfService {
  static Future<void> generateInventoryReport(List<Item> items) async {
    final pdf = pw.Document();
    final NumberFormat currencyFormat = NumberFormat.simpleCurrency();
    final DateTime now = DateTime.now();

    // 1. Calculate Summary Data
    double totalValue = items.fold(0, (sum, item) => sum + item.value);

    // Group items by Room for the summary table
    Map<String, List<Item>> itemsByRoom = {};
    for (var item in items) {
      final room = item.room ?? "Unassigned";
      itemsByRoom.putIfAbsent(room, () => []).add(item);
    }

    // --- PAGE 1: PROFESSIONAL COVER & SUMMARY TABLE ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("HOME INVENTORY REPORT",
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Generated on: ${DateFormat.yMMMMd().format(now)}"),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Column(
                  children: [
                    pw.Text("TOTAL ESTIMATED VALUE", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(currencyFormat.format(totalValue),
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // Compressed Summary Table
          pw.Text("Inventory Overview", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            cellHeight: 25,
            columnWidths: {
              0: const pw.FlexColumnWidth(3), // Name
              1: const pw.FlexColumnWidth(2), // Room/Cat
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

    // --- APPENDIX: PHOTO EVIDENCE GRID ---
    // Insurance prefers photos at the end to keep the data table clean
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: "Photo Appendix"),
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
                    // Main Item Image
                    pw.Expanded(
                      child: item.imagePaths.isNotEmpty
                          ? pw.Image(pw.MemoryImage(File(item.imagePaths[0]).readAsBytesSync()), fit: pw.BoxFit.cover)
                          : pw.Container(color: PdfColors.grey300),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text("${item.room ?? 'General'} | ${currencyFormat.format(item.value)}", style: const pw.TextStyle(fontSize: 8)),
                    if (item.receiptIndices.isNotEmpty)
                      pw.Text("✓ Receipt Attached", style: pw.TextStyle(fontSize: 8, color: PdfColors.green)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    // --- OPTIONAL: HIGH VALUE DETAIL PAGES ---
    // Create dedicated pages only for items over a certain threshold (e.g., $1000)
    final highValueItems = items.where((i) => i.value >= 1000).toList();
    if (highValueItems.isNotEmpty) {
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
                          ? pw.Image(pw.MemoryImage(File(item.imagePaths[0]).readAsBytesSync()))
                          : pw.Container(),
                    ),
                  ],
                ),
                if (item.notes != null) ...[
                  pw.SizedBox(height: 20),
                  pw.Text("Description/Notes:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(item.notes!),
                ],
              ],
            ),
          ),
        );
      }
    }

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: "$label: ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}