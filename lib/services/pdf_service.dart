import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/item.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateInventoryReport(List<Item> items) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.simpleCurrency();
    final dateFormat = DateFormat.yMMMd();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeader(items.length, items.fold(0.0, (sum, item) => sum + item.value)),
          pw.SizedBox(height: 20),

          // Generate a row for every item
          ...items.map((item) => _buildItemRow(item, currencyFormat, dateFormat)).toList(),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'inventory_report.pdf');
  }

  static pw.Widget _buildHeader(int count, double total) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("Home Inventory Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text("Generated on: ${DateFormat.yMMMd().format(DateTime.now())}"),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Total Items: $count"),
            pw.Text("Total Value: ${NumberFormat.simpleCurrency().format(total)}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemRow(Item item, NumberFormat currency, DateFormat date) {
    // Point 8 & 11: Defensive Image Loading
    pw.MemoryImage? imageProvider;

    if (item.imagePaths.isNotEmpty) {
      try {
        final file = File(item.imagePaths[0]);
        // Point 8: Verify existence so readAsBytesSync doesn't throw a FileSystemException
        if (file.existsSync()) {
          // Point 11: In a production app, we would ideally use a resized
          // thumbnail here to save RAM, but checking existence is the first priority.
          imageProvider = pw.MemoryImage(file.readAsBytesSync());
        }
      } catch (e) {
        // If something goes wrong with a specific image, we log it and
        // let the PDF continue generating without that image.
        print("Error loading image for PDF: $e");
      }
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Image Thumbnail with fixed sizing to prevent layout shifts
          pw.Container(
            width: 80,
            height: 80,
            color: PdfColors.grey100, // Light background for missing images
            child: imageProvider != null
                ? pw.Image(imageProvider, fit: pw.BoxFit.cover)
                : pw.Center(
              child: pw.Text(
                item.imagePaths.isEmpty ? "No Photo" : "Photo Error",
                style: const pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
          pw.SizedBox(width: 15),
          // Details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.SizedBox(height: 2),
                pw.Text("Room: ${item.room ?? 'N/A'} | Category: ${item.category ?? 'N/A'}", style: const pw.TextStyle(fontSize: 9)),
                if (item.serialNumber != null && item.serialNumber!.isNotEmpty)
                  pw.Text("Serial: ${item.serialNumber}", style: const pw.TextStyle(fontSize: 9)),
                pw.Text("Purchased: ${date.format(item.purchaseDate)}", style: const pw.TextStyle(fontSize: 9)),
                if (item.notes != null && item.notes!.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text("Notes: ${item.notes}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ),
              ],
            ),
          ),
          pw.Text(currency.format(item.value), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}