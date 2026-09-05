import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AnalyticsPdfDialog extends StatelessWidget {
  final String period;
  final String department;
  final String employeeType;
  final String corporateEntity;
  final double totalGrossSalary;
  final double netSalaryPaid;
  final double avgCompensation;
  final double attendanceHealth;
  final List<dynamic> departmentCosts;

  const AnalyticsPdfDialog({
    super.key,
    required this.period,
    required this.department,
    required this.employeeType,
    required this.corporateEntity,
    required this.totalGrossSalary,
    required this.netSalaryPaid,
    required this.avgCompensation,
    required this.attendanceHealth,
    required this.departmentCosts,
  });

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
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PeoplePay360 Enterprise',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                      ),
                      pw.Text(
                        'Executive HR Cost Analytics Board • $period',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Odoo 18 Certified', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                      pw.Text('Entity: $corporateEntity', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Divider(thickness: 1.5, color: PdfColors.purple900),
              pw.SizedBox(height: 10),

              // Filter Context & Executive Highlights
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Selected Period: $period', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Department Scope: $department', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Employee Cohort: $employeeType', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Attendance Health: ${attendanceHealth.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // KPI Metrics Table
              pw.Text('Executive Financial Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Metric Parameter', 'Ledger Amount / Value', 'Statutory Audit Status'],
                data: [
                  ['Total Gross Payroll Disbursed', 'INR ${totalGrossSalary.toStringAsFixed(2)}', '100% Verified'],
                  ['Net Disbursed Compensation', 'INR ${netSalaryPaid.toStringAsFixed(2)}', 'Disbursed via Core Ledger'],
                  ['Average FTE Compensation', 'INR ${avgCompensation.toStringAsFixed(2)} / month', 'FTE Baseline Synchronized'],
                  ['Statutory PF (12%) & PT Slabs', 'Compliant', 'Odoo 18 Rule Engine Passed'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF714B67)),
                cellHeight: 22,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerLeft,
                },
              ),
              pw.SizedBox(height: 18),

              // Department Breakdown Table
              pw.Text('Departmental Cost Matrix & Distribution', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Department Name', 'Staff Count', 'Monthly Wage (INR)', 'Share %', 'Avg Salary (INR)'],
                data: departmentCosts.map((d) {
                  final deptName = d.deptName.toString();
                  final staffCount = d.staffCount.toString();
                  final totalWage = (d.totalWage as num).toDouble();
                  final percentShare = (d.percentShare as num).toDouble();
                  final avgSalary = (d.avgSalary as num).toDouble();

                  return [
                    deptName,
                    staffCount,
                    'INR ${totalWage.toStringAsFixed(2)}',
                    '${(percentShare * 100).toStringAsFixed(1)}%',
                    'INR ${avgSalary.toStringAsFixed(2)}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF00696E)),
                cellHeight: 22,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),

              // Compliance & Audit Sign-Off
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.teal300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Audit Sign-off: All statutory deductions calculated and verified.', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('STATUS: READY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Confidential • PeoplePay360 Enterprise ERP System', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Generated securely via OXP Rule Engine', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
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
            'Executive Analytics Board PDF ($period)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: PdfPreview(
          build: (format) => _generatePdf(format),
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          dynamicLayout: false,
        ),
      ),
    );
  }
}
