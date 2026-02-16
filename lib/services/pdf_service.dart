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

    // We use a MultiPage to handle long lists that span multiple pages
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
    // We try to load the first image. If it fails or is empty, we show a placeholder.
    pw.MemoryImage? imageProvider;
    if (item.imagePaths.isNotEmpty) {
      final file = File(item.imagePaths[0]);
      if (file.existsSync()) {
        imageProvider = pw.MemoryImage(file.readAsBytesSync());
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
          // Image Thumbnail
          pw.Container(
            width: 80,
            height: 80,
            child: imageProvider != null
                ? pw.Image(imageProvider, fit: pw.BoxFit.cover)
                : pw.Center(child: pw.Text("No Image", style: const pw.TextStyle(fontSize: 8))),
          ),
          pw.SizedBox(width: 15),
          // Details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text("Room: ${item.room ?? 'N/A'} | Category: ${item.category ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
                if (item.serialNumber != null && item.serialNumber!.isNotEmpty)
                  pw.Text("Serial: ${item.serialNumber}", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("Purchased: ${date.format(item.purchaseDate)}", style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.Text(currency.format(item.value), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}