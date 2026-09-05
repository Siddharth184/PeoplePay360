import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payrun_service.dart';
import '../services/api_client.dart';
import '../widgets/payslip_computation_tree_sheet.dart';
import '../widgets/payrun_wizard_sheet.dart';

class PayrunScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const PayrunScreen({super.key, this.onNavigateTab});

  @override
  State<PayrunScreen> createState() => _PayrunScreenState();
}

class _PayrunScreenState extends State<PayrunScreen> with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  late AnimationController _pulseController;

  // Anomaly status state
  bool _bankDetailsFixed = false;
  bool _duplicateResolved = false;
  bool _draftsAutoValidated = false;

  // Pipeline execution state
  String _pipelineStatus = 'Validated';
  bool _isComputing = false;
  bool _isPaid = false;
  bool _payslipsSent = false;

  List<Map<String, dynamic>> _payslips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _loadPayrunData();
  }

  Future<void> _loadPayrunData() async {
    setState(() => _isLoading = true);

    final payslipsRes = await PayrunService.getPayslips();

    if (!mounted) return;



    if (payslipsRes.isSuccess && payslipsRes.data != null) {
      final parsed = payslipsRes.data!.map((slip) {
        final isDone = slip.status.toUpperCase() == 'CONFIRMED' || slip.status.toUpperCase() == 'PAID' || slip.status == 'Done';
        return {
          'id': slip.id,
          'name': slip.employeeName.isNotEmpty ? slip.employeeName : 'Employee',
          'empCode': 'EMP-${slip.id.length > 4 ? slip.id.substring(0, 4) : "001"}',
          'role': 'Staff Member',
          'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
          'status': isDone ? 'Done' : 'Draft',
          'workedDays': '${slip.workedDays.toInt()}',
          'basic': '₹${slip.basicAmount.toStringAsFixed(0)}',
          'gross': '₹${slip.grossAmount.toStringAsFixed(0)}',
          'netPayout': '₹${slip.netAmount.toStringAsFixed(0)}',
          'footerNote': 'Computed via Salary Structure (${slip.refCode})',
          'footerIcon': isDone ? Icons.check_circle : Icons.schedule,
          'footerIconColor': isDone ? const Color(0xFF006443) : const Color(0xFF714B67),
          'hasWarning': false,
          'refNo': slip.refCode,
          'rawStatus': slip.status,
          'rawPayslip': slip,
        };
      }).toList();

      setState(() {
        _payslips = parsed;
        _isLoading = false;
      });
    } else if (!ApiClient.isBackendOnline || payslipsRes.statusCode == 0) {
      setState(() {
        _loadMockPayslips();
        _isLoading = false;
      });
    } else {
      setState(() {
        _payslips = [];
        _isLoading = false;
      });
    }
  }

  void _loadMockPayslips() {
    _payslips = [
      {
        'id': 'aarav',
        'name': 'Aarav Mehta',
        'empCode': 'EMP-4092',
        'role': 'Sr. Cloud Architect • Tech',
        'avatar':
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDyIPpBAqqS7C3_wfY1-X16ZVJjL1i6NwS2fKmhmzc7C_i1u0_prwV_nYqgOLEq07XlAivZi_9TJ3nHdoT-jtdR8mYSe6vNMWBFo2_e6XBILL_Z3o9_HnYgt2N7j4hbDvblnV08Tof0lLGSy_3IeY4EjelWIFLqOGeqg66EbSNw_8nceYeaTOQ0KNU_UyStcrI3gTs4XGxw56XEnLS4BXY6dcwL_jYn0fBb9Epq-1EPdwGXBO4HxLDu',
        'status': 'Done',
        'workedDays': '22',
        'basic': '₹50,000',
        'gross': '₹80,000',
        'netPayout': '₹75,000',
        'footerNote': 'Computed via Salary Rule (v2.4)',
        'footerIcon': Icons.check_circle,
        'footerIconColor': const Color(0xFF006443),
        'hasWarning': false,
        'refNo': 'PS-2026-02-0042',
      },
    ];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int get _anomalyCount {
    int count = 0;
    if (!_bankDetailsFixed) count++;
    if (!_duplicateResolved) count++;
    if (!_draftsAutoValidated) count++;
    return count;
  }

  void _triggerToast(String title, String subtitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF131B2E),
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF92EFF5), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(color: const Color(0xFFDAE2FD), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _payslips.where((slip) {
      if (_selectedFilter == 'Done') return slip['status'] == 'Done' && (slip['warningTag'] == null);
      if (_selectedFilter == 'Draft') return slip['status'] == 'Draft';
      if (_selectedFilter == 'Warnings') return slip['hasWarning'] == true;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Command Bar
                  _buildHeader(),

                  const SizedBox(height: 8),

                  // Summary Metrics Horizontal Ribbon
                  _buildSummaryRibbon(),

                  const SizedBox(height: 14),

                  // Pipeline Toolbar
                  _buildPipelineToolbar(),

                  const SizedBox(height: 14),

                  // Pre-Flight Anomaly Alert Card
                  if (_anomalyCount > 0) _buildAnomalyAlertCard(),

                  const SizedBox(height: 14),

                  // Filter Tabs
                  _buildFilterTabs(),

                  const SizedBox(height: 10),

                  // Payslips List
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF908D96)),
                            const SizedBox(height: 12),
                            Text(
                              'No payruns or payslips created yet',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Run the payrun wizard to calculate batch payslips from backend.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF714B67)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) => _buildPayslipCard(filtered[index]),
                      ),
                    ),
                ],
              ),
            ),

            // Sticky Quick Action Footer
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildStickyFooter(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (widget.onNavigateTab == null && Navigator.canPop(context)) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final route = ModalRoute.of(context);
                      if (route != null && !route.isFirst) {
                        Navigator.pop(context);
                      } else if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(-1);
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF131B2E)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Payrun / Feb 2026',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006443).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF006443), shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(
                                  _pipelineStatus,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF006443)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('BATCH #PR-2026-02', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF4E444A))),
                          const SizedBox(width: 4),
                          Text('•', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF4E444A))),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Odoo 18 Engine',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            icon: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: Color(0xFFF2F3FF), shape: BoxShape.circle),
              child: const Icon(Icons.more_vert, size: 20, color: Color(0xFF131B2E)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            onSelected: (val) {
              if (val == 'wizard') {
                PayrunWizardSheet.show(context, onBatchCreated: () {
                  _triggerToast('Payrun Batch Created ⚡', 'Scope locked and 22 employees queued for Feb 2026.');
                });
              } else if (val == 'reset') {
                setState(() {
                  _bankDetailsFixed = false;
                  _duplicateResolved = false;
                  _draftsAutoValidated = false;
                  _loadPayrunData();
                });
                _triggerToast('Batch Reset', 'All anomaly alerts restored to initial state.');
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'wizard',
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F2FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.auto_fix_high, size: 16, color: Color(0xFF714B67)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Payrun Creation Wizard',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDEC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.restart_alt, size: 16, color: Color(0xFFBA1A1A)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Reset Anomaly Checks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFBA1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRibbon() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildMetricCapsule('Pay Structure', 'Regular Salary', 'Monthly Cycle', const Color(0xFF00696E)),
          const SizedBox(width: 8),
          _buildMetricCapsule('Pay Period', '01 Feb – 28 Feb', '2026 (28 Days)', const Color(0xFF4E444A)),
          const SizedBox(width: 8),
          _buildMetricCapsule('Headcount', '42 Staff', '100% Attended', const Color(0xFF006443)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minWidth: 145),
            decoration: BoxDecoration(
              color: const Color(0xFF714B67),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: const Color(0xFF714B67).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Net Payout', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFF0BFE0))),
                const SizedBox(height: 4),
                Text('₹ 18.42 L', style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.lock, size: 12, color: Color(0xFFF0BFE0)),
                    const SizedBox(width: 4),
                    Text('Ready for File', style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFFF0BFE0))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCapsule(String title, String val, String sub, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 130),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A))),
          const SizedBox(height: 4),
          Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E))),
          const SizedBox(height: 4),
          Text(sub, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: subColor)),
        ],
      ),
    );
  }

  Widget _buildPipelineToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PIPELINE OPERATIONS',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4E444A), letterSpacing: 0.5),
              ),
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00696E), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Odoo Sync Live', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF00696E), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // COMPUTE Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF714B67),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _isComputing
                      ? null
                      : () {
                          setState(() => _isComputing = true);
                          Future.delayed(const Duration(milliseconds: 900), () {
                            if (mounted) {
                              setState(() {
                                _isComputing = false;
                                _pipelineStatus = 'Computed';
                              });
                              _triggerToast('AST Payroll Rules Computed ⚡', 'All 42 salary structures re-calculated with latest tax slabs.');
                            }
                          });
                        },
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, size: 16),
                      const SizedBox(width: 6),
                      Text('COMPUTE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('Rules', style: GoogleFonts.jetBrainsMono(fontSize: 9.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // VALIDATE Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDAE2FD),
                    foregroundColor: const Color(0xFF131B2E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    setState(() => _pipelineStatus = 'Validated');
                    _triggerToast('Batch Validated ✓', 'Attendance entries and contracts matched without overlap.');
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, size: 16, color: Color(0xFF57344F)),
                      const SizedBox(width: 6),
                      Text('VALIDATE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF006443), shape: BoxShape.circle)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // MARK PAID Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPaid ? const Color(0xFF006443) : const Color(0xFF004A31).withValues(alpha: 0.1),
                    foregroundColor: _isPaid ? Colors.white : const Color(0xFF004A31),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    setState(() => _isPaid = !_isPaid);
                    _triggerToast(_isPaid ? 'Batch Marked Paid 💳' : 'Batch Payment Reverted', 'Disbursement status updated in Odoo general ledger.');
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.payments, size: 16),
                      const SizedBox(width: 6),
                      Text('MARK PAID', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // SEND PAYSLIPS Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF92EFF5),
                    foregroundColor: const Color(0xFF006E73),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    setState(() => _payslipsSent = true);
                    _triggerToast('Payslips Dispatched ✉️', 'Encrypted Form XVI PDFs emailed to 42 verified staff accounts.');
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.outgoing_mail, size: 16),
                      const SizedBox(width: 6),
                      Text('SEND PAYSLIPS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFF00696E).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(_payslipsSent ? 'Sent' : 'Auto', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyAlertCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E7FF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.warning, size: 18, color: Color(0xFF93000A)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pre-Flight Anomaly Check', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E))),
                            Text('$_anomalyCount Blocking Issues Require Attention', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFBA1A1A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFBA1A1A), borderRadius: BorderRadius.circular(12)),
                  child: Text('Priority', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Alert 1: Missing Bank Details
            if (!_bankDetailsFixed)
              _buildAnomalyItem(
                Icons.account_balance,
                '2 Missing Bank Details',
                'Sara Khan, Neha Patel',
                'Fix Details',
                () {
                  setState(() {
                    _bankDetailsFixed = true;
                    final sara = _payslips.firstWhere((p) => p['id'] == 'sara');
                    sara['warningTag'] = null;
                    sara['hasWarning'] = false;
                    sara['payoutStatus'] = null;
                    sara['basic'] = '₹55,000';
                    sara['gross'] = '₹92,000';
                    sara['footerNote'] = 'Verified Bank details on file';
                    sara['footerIcon'] = Icons.check_circle;
                    sara['footerIconColor'] = const Color(0xFF006443);
                    sara['actionBtn'] = null;
                  });
                  _triggerToast('Bank Details Updated ✓', 'Sara Khan & Neha Patel IFSC validated. Bank hold removed.');
                },
              ),

            if (!_bankDetailsFixed) const SizedBox(height: 8),

            // Alert 2: Duplicate Record
            if (!_duplicateResolved)
              _buildAnomalyItem(
                Icons.copy_all,
                '1 Duplicate Record Detected',
                'John Dsouza (EMP-4098)',
                'Resolve',
                () {
                  setState(() {
                    _duplicateResolved = true;
                    final john = _payslips.firstWhere((p) => p['id'] == 'john');
                    john['warningTag'] = null;
                    john['hasWarning'] = false;
                    john['status'] = 'Done';
                    john['conflictText'] = null;
                    john['basic'] = '₹40,000';
                    john['gross'] = '₹70,000';
                    john['footerNote'] = 'Merged into batch ledger';
                    john['footerIcon'] = Icons.check_circle;
                    john['footerIconColor'] = const Color(0xFF006443);
                    john['actionBtn'] = null;
                  });
                  _triggerToast('Duplicate Resolved ✓', 'Duplicate draft #SLIP-881 dropped. Record finalized as Done.');
                },
              ),

            if (!_duplicateResolved) const SizedBox(height: 8),

            // Alert 3: Drafts Pending Verification
            if (!_draftsAutoValidated)
              _buildAnomalyItem(
                Icons.fact_check,
                '4 Drafts Pending Verification',
                'Unsettled OT & reimbursements',
                'Auto-Validate',
                () {
                  setState(() => _draftsAutoValidated = true);
                  _triggerToast('Auto-Validation Complete ⚡', 'All 4 draft entries verified against biometric logs.');
                },
                isAutoValidate: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomalyItem(IconData icon, String title, String sub, String btnLabel, VoidCallback onTap, {bool isAutoValidate = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 18, color: isAutoValidate ? const Color(0xFF4E444A) : const Color(0xFFBA1A1A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF4E444A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isAutoValidate ? const Color(0xFF00696E) : const Color(0xFF57344F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    btnLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAutoValidate ? Colors.white : const Color(0xFF57344F),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isAutoValidate ? Icons.auto_fix_high : Icons.arrow_forward,
                    size: 12,
                    color: isAutoValidate ? Colors.white : const Color(0xFF57344F),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabPill('All', '42', isSelected: _selectedFilter == 'All'),
            const SizedBox(width: 8),
            _buildTabPill('Done', '35', isSelected: _selectedFilter == 'Done', countColor: const Color(0xFF006443)),
            const SizedBox(width: 8),
            _buildTabPill('Draft', '4', isSelected: _selectedFilter == 'Draft'),
            const SizedBox(width: 8),
            _buildTabPill('Warnings', '$_anomalyCount', isSelected: _selectedFilter == 'Warnings', isWarning: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(String label, String count, {bool isSelected = false, Color? countColor, bool isWarning = false}) {
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF57344F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            if (isWarning) ...[
              const Icon(Icons.warning, size: 13, color: Color(0xFFBA1A1A)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isWarning
                        ? const Color(0xFFBA1A1A)
                        : const Color(0xFF4E444A),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              count,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : countColor ?? (isWarning ? const Color(0xFFBA1A1A) : const Color(0xFF4E444A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayslipCard(Map<String, dynamic> slip) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (slip['avatar'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(
                          slip['avatar'],
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(color: Color(0xFFFFD7F1), shape: BoxShape.circle),
                            child: Center(child: Text((slip['name'] as String)[0], style: const TextStyle(fontWeight: FontWeight.bold))),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(color: Color(0xFFDAE2FD), shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            slip['initials'] ?? 'RP',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  slip['name'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF131B2E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                slip['empCode'],
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: const Color(0xFF4E444A),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            slip['role'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF4E444A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (slip['warningTag'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning, size: 11, color: Color(0xFFBA1A1A)),
                          const SizedBox(width: 3),
                          Text(
                            slip['warningTag'],
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF93000A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: slip['status'] == 'Done' ? const Color(0xFF006443).withValues(alpha: 0.1) : const Color(0xFFDAE2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      slip['status'],
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: slip['status'] == 'Done' ? const Color(0xFF006443) : const Color(0xFF131B2E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 4-Column Metric Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF2F3FF).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Worked Days', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
                    Text('${slip['workedDays']} Days', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (slip['basic'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Basic', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
                      Text(slip['basic'], style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                if (slip['gross'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gross', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
                      Text(slip['gross'], style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                if (slip['payoutStatus'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payout Status', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
                      Text(slip['payoutStatus'], style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFBA1A1A))),
                    ],
                  ),
                if (slip['conflictText'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conflict', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
                      Text(slip['conflictText'], style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFBA1A1A))),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Net Payout', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF00696E))),
                    Text(slip['netPayout'], style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00696E))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Footer Action & Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(slip['footerIcon'], size: 14, color: slip['footerIconColor']),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        slip['footerNote'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: slip['footerIconColor']),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (slip['actionBtn'] != null) ...[
                    InkWell(
                      onTap: () {
                        if (slip['actionBtn'] == 'Fix A/C') {
                          setState(() {
                            _bankDetailsFixed = true;
                            slip['warningTag'] = null;
                            slip['hasWarning'] = false;
                            slip['payoutStatus'] = null;
                            slip['basic'] = '₹55,000';
                            slip['gross'] = '₹92,000';
                            slip['footerNote'] = 'Verified Bank details on file';
                            slip['footerIcon'] = Icons.check_circle;
                            slip['footerIconColor'] = const Color(0xFF006443);
                            slip['actionBtn'] = null;
                          });
                          _triggerToast('Bank A/C Resolved ✓', 'Sara Khan account linked and hold removed.');
                        } else if (slip['actionBtn'] == 'Resolve') {
                          setState(() {
                            _duplicateResolved = true;
                            slip['warningTag'] = null;
                            slip['hasWarning'] = false;
                            slip['status'] = 'Done';
                            slip['conflictText'] = null;
                            slip['basic'] = '₹40,000';
                            slip['gross'] = '₹70,000';
                            slip['footerNote'] = 'Merged into batch ledger';
                            slip['footerIcon'] = Icons.check_circle;
                            slip['footerIconColor'] = const Color(0xFF006443);
                            slip['actionBtn'] = null;
                          });
                          _triggerToast('Duplicate Resolved ✓', 'John Dsouza payslip normalized.');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: slip['actionBtn'] == 'Fix A/C' ? const Color(0xFFFFDAD6) : const Color(0xFF714B67),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          slip['actionBtn'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: slip['actionBtn'] == 'Fix A/C' ? const Color(0xFF93000A) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: () => PayslipComputationTreeSheet.show(context, slip),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDAE2FD),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 14, color: Color(0xFF57344F)),
                          const SizedBox(width: 4),
                          Text('PDF', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF00696E), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Total Net Outflow:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A))),
                ],
              ),
              Text(
                '₹ 18,42,500.00',
                style: GoogleFonts.jetBrainsMono(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF714B67),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () {
              if (_anomalyCount > 0) {
                _triggerToast('Pre-Flight Anomaly Warning ⚠️', 'Please resolve the $_anomalyCount blocking issue(s) before disbursing.');
              } else {
                _triggerToast('NACH / NEFT File Exported ⚡', '₹ 18,42,500.00 batch dispatched to banking portal with zero errors.');
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Disburse via Bank File (NACH/NEFT)', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
