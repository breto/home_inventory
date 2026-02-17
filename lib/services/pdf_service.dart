import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';

class PdfService {
  static Future<void> generateInventoryReport(List<Item> items) async {
    final pdf = pw.Document();
    final totalValue = items.fold<double>(0, (sum, item) => sum + item.value);
    final currencyFormat = NumberFormat.simpleCurrency();

    // --- Page 1: Summary / Cover Page ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Home Inventory Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat.yMMMd().format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat("Total Items", items.length.toString()),
                _buildSummaryStat("Total Value", currencyFormat.format(totalValue)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            context: context,
            data: <List<String>>[
              <String>['Name', 'Room', 'Category', 'Value'],
              ...items.map((i) => [i.name, i.room ?? 'N/A', i.category ?? 'N/A', currencyFormat.format(i.value)]),
            ],
          ),
        ],
      ),
    );

    // --- Detail Pages: Items & Images ---
    for (var item in items) {
      final List<pw.Widget> imageWidgets = [];

      // Convert file paths to PDF Images
      for (int i = 0; i < item.imagePaths.length; i++) {
        final file = File(item.imagePaths[i]);
        if (await file.exists()) {
          final image = pw.MemoryImage(file.readAsBytesSync());
          final isReceipt = item.receiptIndices.contains(i);

          imageWidgets.add(
            pw.Container(
              margin: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: isReceipt ? PdfColors.green : PdfColors.grey300, width: 2),
              ),
              child: pw.Stack(
                alignment: pw.Alignment.bottomCenter,
                children: [
                  pw.Image(image, width: 150, height: 150, fit: pw.BoxFit.cover),
                  if (isReceipt)
                    pw.Container(
                      width: 150,
                      color: PdfColors.green,
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text("RECEIPT",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        }
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 1, text: item.name),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildDetailText("Value:", currencyFormat.format(item.value)),
                        _buildDetailText("Room:", item.room ?? "N/A"),
                        _buildDetailText("Category:", item.category ?? "N/A"),
                        _buildDetailText("Purchase Date:", DateFormat.yMMMd().format(item.purchaseDate)),
                        if (item.brand != null) _buildDetailText("Brand:", item.brand!),
                        if (item.model != null) _buildDetailText("Model:", item.model!),
                        if (item.serialNumber != null) _buildDetailText("Serial:", item.serialNumber!),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Notes:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(item.notes ?? "No notes provided."),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text("Photos & Proof of Purchase:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Wrap(children: imageWidgets),
            ],
          ),
        ),
      );
    }

    // Output the PDF to the native Print/Share dialog
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildSummaryStat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildDetailText(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: "$label ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}