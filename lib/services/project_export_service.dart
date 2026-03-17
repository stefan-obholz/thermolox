import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project_models.dart';
import '../models/project_measurement.dart';

class ProjectExportService {
  const ProjectExportService._();

  static Future<Uint8List> generatePdf({
    required Project project,
    ProjectMeasurement? measurement,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await _loadFont('Roboto-Regular'),
        bold: await _loadFont('Roboto-Bold'),
      ),
    );

    final projectName = (project.title ?? project.name).trim();
    final notes = project.items.where((i) => i.type == 'note').toList();
    final colors = project.items.where((i) => i.type == 'color').toList();
    final images = project.items.where((i) => i.type == 'image').toList();
    final renders = project.items.where((i) => i.type == 'render').toList();

    // Load project images
    final imageWidgets = <pw.Widget>[];
    for (final item in [...images, ...renders]) {
      final bytes = await _loadItemBytes(item);
      if (bytes != null) {
        final label = item.type == 'render' ? 'Rendering' : 'Raumfoto';
        final colorInfo =
            item.colorHex != null ? ' (${item.colorHex})' : '';
        imageWidgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$label$colorInfo',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Image(pw.MemoryImage(bytes), height: 200, fit: pw.BoxFit.contain),
              pw.SizedBox(height: 12),
            ],
          ),
        );
      }
    }

    // Load logo
    pw.MemoryImage? logoImage;
    try {
      final logoData =
          await rootBundle.load('assets/logos/CLIMALOX_SYSTEMS.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(projectName, logoImage),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Measurement section
          if (measurement != null) ...[
            _sectionTitle('Raummasse'),
            _measurementTable(measurement),
            pw.SizedBox(height: 16),
          ],

          // Colors
          if (colors.isNotEmpty) ...[
            _sectionTitle('Farbauswahl'),
            ...colors.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(children: [
                    if (c.colorHex != null)
                      pw.Container(
                        width: 16,
                        height: 16,
                        margin: const pw.EdgeInsets.only(right: 8),
                        decoration: pw.BoxDecoration(
                          color: _pdfColorFromHex(c.colorHex!),
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                      ),
                    pw.Text(c.name),
                  ]),
                )),
            pw.SizedBox(height: 16),
          ],

          // Notes
          if (notes.isNotEmpty) ...[
            _sectionTitle('Notizen'),
            ...notes.map((n) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(n.name),
                )),
            pw.SizedBox(height: 16),
          ],

          // Images
          if (imageWidgets.isNotEmpty) ...[
            _sectionTitle('Bilder'),
            ...imageWidgets,
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
      String projectName, pw.MemoryImage? logo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                projectName,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (logo != null) pw.Image(logo, height: 28),
          ],
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Erstellt mit CLIMALOX',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Seite ${context.pageNumber} von ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
      ),
    );
  }

  static pw.Widget _measurementTable(ProjectMeasurement m) {
    final rows = <List<String>>[];
    if (m.lengthM != null) rows.add(['Laenge', '${m.lengthM!.toStringAsFixed(2)} m']);
    if (m.widthM != null) rows.add(['Breite', '${m.widthM!.toStringAsFixed(2)} m']);
    if (m.heightM != null) rows.add(['Hoehe', '${m.heightM!.toStringAsFixed(2)} m']);
    if (m.lengthM != null && m.widthM != null) {
      final area = m.lengthM! * m.widthM!;
      rows.add(['Grundflaeche', '${area.toStringAsFixed(2)} m²']);
    }
    if (m.lengthM != null && m.widthM != null && m.heightM != null) {
      final wallArea =
          2 * (m.lengthM! + m.widthM!) * m.heightM!;
      final openingArea =
          m.openings.fold(0.0, (sum, o) => sum + o.area);
      rows.add(['Wandflaeche (brutto)', '${wallArea.toStringAsFixed(2)} m²']);
      rows.add([
        'Wandflaeche (netto)',
        '${(wallArea - openingArea).clamp(0.0, double.infinity).toStringAsFixed(2)} m²',
      ]);
    }
    if (m.openings.isNotEmpty) {
      for (final o in m.openings) {
        final typeLabel = o.type == 'window'
            ? 'Fenster'
            : o.type == 'door'
                ? 'Tuer'
                : 'Oeffnung';
        rows.add([
          '$typeLabel (${o.count}x)',
          '${o.widthM.toStringAsFixed(2)} x ${o.heightM.toStringAsFixed(2)} m',
        ]);
      }
    }
    rows.add(['Methode', m.method == 'lidar_roomplan' ? 'LiDAR' : 'Foto/Manuell']);

    return pw.TableHelper.fromTextArray(
      headers: ['Eigenschaft', 'Wert'],
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  static PdfColor _pdfColorFromHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length < 6) h = h.padRight(6, '0');
    final val = int.tryParse(h.substring(0, 6), radix: 16) ?? 0x777777;
    return PdfColor(
      ((val >> 16) & 0xFF) / 255.0,
      ((val >> 8) & 0xFF) / 255.0,
      (val & 0xFF) / 255.0,
    );
  }

  static Future<Uint8List?> _loadItemBytes(ProjectItem item) async {
    try {
      if (item.path != null && item.path!.isNotEmpty) {
        final file = File(item.path!);
        if (await file.exists()) return file.readAsBytes();
      }
      // Remote URLs are not included in PDF to keep it offline-capable
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<pw.Font> _loadFont(String name) async {
    try {
      if (name.contains('Bold')) return await PdfGoogleFonts.robotoBold();
      return await PdfGoogleFonts.robotoRegular();
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  /// Share as PDF file
  static Future<void> sharePdf({
    required Project project,
    ProjectMeasurement? measurement,
  }) async {
    final bytes = await generatePdf(
      project: project,
      measurement: measurement,
    );
    final dir = await getTemporaryDirectory();
    final name = (project.title ?? project.name)
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final file = File('${dir.path}/CLIMALOX_$name.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'CLIMALOX Projekt: ${(project.title ?? project.name).trim()}',
    );
  }

  /// Print directly
  static Future<void> printPdf({
    required Project project,
    ProjectMeasurement? measurement,
  }) async {
    final bytes = await generatePdf(
      project: project,
      measurement: measurement,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'CLIMALOX_${(project.title ?? project.name).trim()}',
    );
  }
}
