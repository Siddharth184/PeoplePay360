import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import 'payslip_pdf_dialog.dart';

class PayslipComputationTreeSheet extends StatefulWidget {
  final Map<String, dynamic> payslip;

  const PayslipComputationTreeSheet({super.key, required this.payslip});

  static void show(BuildContext context, Map<String, dynamic> payslip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayslipComputationTreeSheet(payslip: payslip),
    );
  }

  @override
  State<PayslipComputationTreeSheet> createState() => _PayslipComputationTreeSheetState();
}

class _PayslipComputationTreeSheetState extends State<PayslipComputationTreeSheet> {
  bool _isTreeTab = true;

  @override
  Widget build(BuildContext context) {
    final slip = widget.payslip;
    final empName = slip['name'] ?? 'Aarav Mehta';
    final empCode = slip['empCode'] ?? 'EMP-4092';
    final role = slip['role'] ?? 'Payroll Specialist • Finance Ops';
    final netPay = slip['netPayout'] ?? '₹ 75,000.00';
    final baseWage = slip['baseWage'] ?? '₹ 85,000';
    final workedDays = slip['workedDays'] ?? '22 / 22 D';
    final refNo = slip['refNo'] ?? 'PS-2026-02-0042';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1C3CA),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F3FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF131B2E)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAYSLIP REFERENCE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4E444A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              refNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6FFBBE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF004A31),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Done',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF002113),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('📥 Downloading $refNo PDF sheet...')),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAEDFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download, size: 18, color: Color(0xFF57344F)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFDAE2FD)),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee Profile & Period Meta Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFD7F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      empName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2F1029),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          empName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF131B2E),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, size: 16, color: Color(0xFF00696E)),
                                      ],
                                    ),
                                    Text(
                                      '$role • $empCode',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF4E444A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Cycle 02', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF4E444A))),
                                Text(
                                  'Active Run',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00696E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F3FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, size: 16, color: Color(0xFF4E444A)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'February 2026',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                                  ),
                                ],
                              ),
                              Text('01-Feb → 28-Feb', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF4E444A))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Quick Stats Grid
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E7FF).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              _buildProfileStat('Base Wage', baseWage, const Color(0xFF131B2E)),
                              const SizedBox(width: 6),
                              _buildProfileStat('Worked Days', workedDays, const Color(0xFF006443)),
                              const SizedBox(width: 6),
                              _buildProfileStat('Schedule', '40h / wk', const Color(0xFF131B2E)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Segmented Switcher
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E7FF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isTreeTab = true),
                            borderRadius: BorderRadius.circular(26),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _isTreeTab ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: _isTreeTab
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_tree,
                                    size: 16,
                                    color: _isTreeTab ? const Color(0xFF57344F) : const Color(0xFF4E444A),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Computation Tree',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: _isTreeTab ? FontWeight.bold : FontWeight.w500,
                                      color: _isTreeTab ? const Color(0xFF57344F) : const Color(0xFF4E444A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isTreeTab = false),
                            borderRadius: BorderRadius.circular(26),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: !_isTreeTab ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: !_isTreeTab
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf,
                                    size: 16,
                                    color: !_isTreeTab ? const Color(0xFF57344F) : const Color(0xFF4E444A),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Official PDF',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12.5,
                                      fontWeight: !_isTreeTab ? FontWeight.bold : FontWeight.w500,
                                      color: !_isTreeTab ? const Color(0xFF57344F) : const Color(0xFF4E444A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_isTreeTab) _buildComputationTreeView(netPay) else _buildOfficialPdfView(empName, empCode, refNo, netPay),
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF714B67),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      try {
                        final raw = widget.payslip['rawPayslip'];
                        final nameFromSheet = widget.payslip['name'] ?? widget.payslip['employeeName'] ?? widget.payslip['employee_name'];
                        PayslipModel model = (raw is PayslipModel) ? raw : PayslipModel.fromJson(widget.payslip);
                        if (nameFromSheet != null && nameFromSheet.toString().isNotEmpty) {
                          model = model.copyWith(employeeName: nameFromSheet.toString());
                        }
                        showDialog(
                          context: context,
                          builder: (context) => PayslipPdfDialog(payslip: model),
                        );
                      } catch (_) {
                        setState(() => _isTreeTab = false);
                      }
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: Text('Print PDF', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF92EFF5),
                      foregroundColor: const Color(0xFF006E73),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🔗 Link copied for $refNo ($empName)')),
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: Text('Share Slip', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(String label, String val, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF4E444A))),
            const SizedBox(height: 2),
            Text(
              val,
              style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: valColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComputationTreeView(String netPay) {
    final slip = widget.payslip;
    final baseWageVal = (slip['contract_wage'] is num)
        ? (slip['contract_wage'] as num).toDouble()
        : (slip['contractMonthlyWage'] is num
            ? (slip['contractMonthlyWage'] as num).toDouble()
            : 85000.0);
    final hourlyRate = baseWageVal / 176.0;
    final otRate = hourlyRate * 1.5;
    final otHours = (slip['overtime_hours'] is num)
        ? (slip['overtime_hours'] as num).toDouble()
        : 10.0;
    final otPay = (slip['overtime_pay'] is num)
        ? (slip['overtime_pay'] as num).toDouble()
        : double.parse((otHours * otRate).toStringAsFixed(2));

    final extraDays = (slip['extra_days'] is num)
        ? (slip['extra_days'] as num).toDouble()
        : 2.0;
    final dailyRate = baseWageVal / 22.0;
    final extraDaysPay = (slip['extra_days_pay'] is num)
        ? (slip['extra_days_pay'] as num).toDouble()
        : double.parse((extraDays * dailyRate).toStringAsFixed(2));

    final totalEarnings = 50000.0 + 20000.0 + 10000.0 + otPay + extraDaysPay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overtime & Extra Days Contract Basis Sidebar Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF92EFF5), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF006E73).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.analytics, size: 18, color: Color(0xFF006E73)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Overtime Earning & Package Rate Basis',
                        style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF92EFF5), borderRadius: BorderRadius.circular(12)),
                    child: Text('1.5x Overtime Rate', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF004F53))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Rate Specs Grid
              Row(
                children: [
                  _buildProfileStat('Contract Wage', '₹ ${baseWageVal.toStringAsFixed(0)}', const Color(0xFF131B2E)),
                  const SizedBox(width: 6),
                  _buildProfileStat('Hourly Rate', '₹ ${hourlyRate.toStringAsFixed(2)}/h', const Color(0xFF00696E)),
                  const SizedBox(width: 6),
                  _buildProfileStat('OT Rate (1.5x)', '₹ ${otRate.toStringAsFixed(2)}/h', const Color(0xFF006443)),
                  const SizedBox(width: 6),
                  _buildProfileStat('Daily Rate', '₹ ${dailyRate.toStringAsFixed(2)}/d', const Color(0xFF57344F)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDAE2FD)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled, size: 15, color: Color(0xFF006E73)),
                            const SizedBox(width: 6),
                            Text('Overtime Earning (${otHours.toStringAsFixed(1)} hrs):', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          '+ ₹ ${otPay.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF006443)),
                        ),
                      ],
                    ),
                    const Divider(height: 12, color: Color(0xFFF0F0F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 15, color: Color(0xFF57344F)),
                            const SizedBox(width: 6),
                            Text('Extra Days Payout (${extraDays.toStringAsFixed(1)} days):', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          '+ ₹ ${extraDaysPay.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF006443)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Allowances & Earnings Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF006443), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Allowances & Earnings', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF6FFBBE), borderRadius: BorderRadius.circular(12)),
                    child: Text('5 Rules', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF004A31))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTreeNode('Basic Salary', 'BASIC', 'Category: Basic • Base 100%', '+ ₹ 50,000.00', 'Direct', Icons.add_circle, const Color(0xFF6FFBBE), const Color(0xFF004A31)),
              const SizedBox(height: 8),
              _buildTreeNode('House Rent Allowance', 'HRA', 'Allowance • 40% of BASIC', '+ ₹ 20,000.00', 'Computed', Icons.domain, const Color(0xFF6FFBBE), const Color(0xFF004A31)),
              const SizedBox(height: 8),
              _buildTreeNode('Standard Allowance', 'STD', 'Allowance • Fixed Rate', '+ ₹ 10,000.00', 'Fixed', Icons.payments, const Color(0xFF6FFBBE), const Color(0xFF004A31)),
              const SizedBox(height: 8),
              _buildTreeNode(
                'Overtime Earning',
                'OT',
                '${otHours.toStringAsFixed(1)}h worked • 1.5x Hourly Rate (₹ ${otRate.toStringAsFixed(2)}/h)',
                '+ ₹ ${otPay.toStringAsFixed(2)}',
                'Overtime',
                Icons.access_time_filled,
                const Color(0xFF92EFF5),
                const Color(0xFF006E73),
              ),
              const SizedBox(height: 8),
              _buildTreeNode(
                'Extra Days Payout',
                'EXT_DAYS',
                '${extraDays.toStringAsFixed(1)} extra days worked • Daily Rate (₹ ${dailyRate.toStringAsFixed(2)}/d)',
                '+ ₹ ${extraDaysPay.toStringAsFixed(2)}',
                'Extra Days',
                Icons.event_available,
                const Color(0xFF6FFBBE),
                const Color(0xFF004A31),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Gross Subtotal Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF92EFF5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: Color(0xFF00696E), shape: BoxShape.circle),
                    child: const Icon(Icons.equalizer, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Gross Salary', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF002022))),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFF006E73).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text('GROSS', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF004F53))),
                          ),
                        ],
                      ),
                      Text('Sum of all active earnings & overtime', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF004F53))),
                    ],
                  ),
                ],
              ),
              Text(
                '= ₹ ${totalEarnings.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF002022)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Deductions & Statutory Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFBA1A1A), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Deductions & Statutory', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(12)),
                    child: Text('2 Rules', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF93000A))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTreeNode('Provident Fund', 'PF', 'Statutory Contribution • 12%', '- ₹ 3,000.00', 'Mandatory', Icons.remove_circle, const Color(0xFFFFDAD6), const Color(0xFF93000A)),
              const SizedBox(height: 8),
              _buildTreeNode('Professional Tax', 'PT', 'State Statutory Slab', '- ₹ 2,000.00', 'Fixed Slab', Icons.receipt_long, const Color(0xFFFFDAD6), const Color(0xFF93000A)),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Net Payable Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF57344F), Color(0xFF714B67)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFF57344F).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Color(0xFFF0BFE0), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'NET SALARY PAYABLE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF0BFE0),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF714B67), borderRadius: BorderRadius.circular(10)),
                    child: Text('NET', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF0BFE0))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                netPay,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Color(0xFFF0BFE0), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Transferred to HDFC Bank A/C ending ••••4921',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFF0BFE0)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTreeNode(String title, String tag, String desc, String amt, String subTag, IconData icon, Color iconBg, Color iconFg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 16, color: iconFg),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFDAE2FD), borderRadius: BorderRadius.circular(4)),
                        child: Text(tag, style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF4E444A))),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amt,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: amt.startsWith('+') ? const Color(0xFF006443) : const Color(0xFFBA1A1A),
                ),
              ),
              Text(subTag, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF4E444A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialPdfView(String empName, String empCode, String refNo, String netPay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDAE2FD)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          // Watermark Stamp
          Positioned(
            right: 10,
            top: 60,
            child: Transform.rotate(
              angle: -0.3,
              child: Opacity(
                opacity: 0.12,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00696E), width: 3),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('OXP PVT LTD', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold)),
                        Text('VERIFIED', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('28-FEB-2026', style: GoogleFonts.jetBrainsMono(fontSize: 7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.corporate_fare, size: 20, color: Color(0xFF57344F)),
                          const SizedBox(width: 6),
                          Text(
                            'OdooXpress India Pvt Ltd',
                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF57344F)),
                          ),
                        ],
                      ),
                      Text('Cyber City, Phase II, Gurugram, HR 122002', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
                      Text('CIN: U72200HR2018PTC099411', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF4E444A))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('FORM XVI', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('Pay Slip [Rule 26(2)]', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: const Color(0xFF4E444A))),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Sheet Metadata Strip
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetaItem('Employee Name:', empName),
                        _buildMetaItem('Emp Code / Dept:', '$empCode • Finance'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetaItem('Pay Period:', '01-Feb-2026 to 28-Feb-2026'),
                        _buildMetaItem('Bank Ref No:', 'HDFC-N9420014'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Mini Table Heads
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFEAEDFF), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Earnings Head & Overtime', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('Amount (INR)', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildTableRow('Basic Salary', '50,000.00'),
              _buildTableRow('House Rent Allowance', '20,000.00'),
              _buildTableRow('Special Allowance', '10,000.00'),
              _buildTableRow('Overtime Earning (10.0h @ 1.5x)', '7,244.30'),
              _buildTableRow('Extra Days Payout (2.0 days)', '7,727.30'),

              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFEAEDFF), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Statutory Deductions', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('Amount (INR)', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildTableRow('PF Employee Share', '3,000.00'),
              _buildTableRow('Professional Tax', '2,000.00'),

              const SizedBox(height: 10),

              // Mini Totals
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFE2E7FF), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Take Home Pay:', style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    Text(netPay, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF57344F))),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Barcode & Signature
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barcode simulation
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            _bar(2, 22), _bar(1, 22), _bar(3, 22), _bar(1, 22), _bar(2, 22), _bar(4, 22),
                            _bar(1, 22), _bar(2, 22), _bar(3, 22), _bar(1, 22), _bar(2, 22), _bar(1, 22),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('$refNo-VERIF', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: const Color(0xFF4E444A))),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Deepak Sharma', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF57344F))),
                      Container(width: 80, height: 1, color: const Color(0xFFD1C3CA), margin: const EdgeInsets.symmetric(vertical: 2)),
                      Text('Authorized Signatory', style: GoogleFonts.plusJakartaSans(fontSize: 8.5, color: const Color(0xFF4E444A))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
        Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E))),
      ],
    );
  }

  Widget _buildTableRow(String head, String amt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(head, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF131B2E))),
          Text(amt, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF131B2E))),
        ],
      ),
    );
  }

  Widget _bar(double width, double height) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      width: width,
      height: height,
      color: const Color(0xFF131B2E),
    );
  }
}
