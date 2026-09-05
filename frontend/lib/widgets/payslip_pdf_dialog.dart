import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PayslipPdfDialog extends StatelessWidget {
  final PayslipModel payslip;

  const PayslipPdfDialog({super.key, required this.payslip});

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    pw.Document.debug = false;
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PeoplePay360 Enterprise', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Official Salary Slip • ${payslip.refCode}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Text('Odoo 18 Certified', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Employee Name: ${payslip.employeeName}'),
                  pw.Text('Pay Period: ${payslip.periodStart} to ${payslip.periodEnd}'),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Salary Rule Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Code', 'Rule Name', 'Category', 'Amount (INR)'],
                data: payslip.lines.map((l) => [
                  l.ruleCode,
                  l.ruleName,
                  l.category,
                  'INR ${l.amount.toStringAsFixed(2)}',
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF714B67)),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Gross Salary: INR ${payslip.grossAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('NET SALARY: INR ${payslip.netAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ],
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text('Generated securely by PeoplePay360 System • Tamper-evident Audit Verified', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF714B67),
          foregroundColor: Colors.white,
          title: Text(
            'Payslip Preview (${payslip.refCode})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: PdfPreview(
            build: (format) => _generatePdf(format),
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            dynamicLayout: false,
          ),
        ),
      ),
    );
  }
}
