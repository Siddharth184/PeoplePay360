import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PayrunWizardSheet extends StatefulWidget {
  final VoidCallback? onBatchCreated;

  const PayrunWizardSheet({super.key, this.onBatchCreated});

  static void show(BuildContext context, {VoidCallback? onBatchCreated}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayrunWizardSheet(onBatchCreated: onBatchCreated),
    );
  }

  @override
  State<PayrunWizardSheet> createState() => _PayrunWizardSheetState();
}

class _PayrunWizardSheetState extends State<PayrunWizardSheet> {
  int _activeStep = 1; // Step 2 (Employees) active as in template
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isGenerating = false;
  bool _isCreated = false;

  late List<Map<String, dynamic>> _employees;

  @override
  void initState() {
    super.initState();
    _employees = [
      {
        'name': 'Anita Oliver',
        'role': 'Full-Time',
        'schedule': '40h/wk',
        'type': 'Regular',
        'since': 'Since Jan 1, 2026',
        'annual': '₹ 4,50,000 / yr',
        'monthly': 37500.0,
        'avatar': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDLB1uPtQb6cTFlvTyBuAmv7SjQhWT9EvyHciGZ433ghnVprpg5npUiD0_lrSCQUcVwlHnPQROZPy-vgmxlEfOKxlia8OwdIM9axK7nvHeC3Zi6f_N9NCgxYt79omfGA-7UIPBUP0FNiL9cLMxlEjgpYk2JcNFmW2sDzBZ9whq_V-pElqt65Ora2imY_Te08Mi2iIMhOL4h9RDKTqNJeBuP_dz9H6-MRXDnL0_DED62pbgQAtMXHil6',
        'selected': true,
      },
      {
        'name': 'Audrey Peterson',
        'role': 'Full-Time',
        'schedule': '40h/wk',
        'type': 'Regular',
        'since': 'Since Jan 1, 2026',
        'annual': '₹ 4,00,000 / yr',
        'monthly': 33333.0,
        'avatar': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAEbCZKQ5JnK5ePNiGoc_HKDR6nnyOxiVGcT8r6H2SQlVLuqh_Kp09kE18BZg2oRiRTn5BZ_M33wFTNE4RbWzMjFScGwJH_0JTNvDE7MfvcaShAph5ipT4hxX3OEPTXi-SNwNc6C7XB0kpAs4--nxeZvpww7ZT1FDHYUEonff7jc00BtDsuR4XNU7sXj-bnSLGuxTTDy10Z2qp8aFgAW8xPE8urw-ddREHpZw8oeR6JRKdlX-g2oPqd',
        'selected': true,
      },
      {
        'name': 'Billy Kyle',
        'role': 'Full-Time',
        'schedule': '40h/wk',
        'isNew': true,
        'type': 'Prorated',
        'since': 'Sep 2, 2026 (Joined)',
        'annual': '₹ 3,10,000 / yr',
        'monthly': 25833.0,
        'avatar': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAtQXPfcIQURcGVXweXs_U1Oqe0HRwLAK-kEicjIX9wkIY0zSO48VegUOOff_YiS-vMe5AX1lep4W6au5GrMZoDgN0MmzT5ACZoW11Q6ESqFfDFJjoqrY2hjQ6ggAbVqiKUedsSNpOYFBo7C4Gxa0UjfqNpn3goAMn1D8YKILFAoW7spt6rdCFUBTPPiC5toxIh1kA3g85eMPECPiXjXEDRq5yz-8IAxWtmPR0DJBS6Nhpf5zXbxzIF',
        'selected': true,
      },
      {
        'name': 'Eli Lambert',
        'role': 'Full-Time',
        'schedule': '40h/wk',
        'type': 'Regular',
        'since': 'Since Jan 1, 2026',
        'annual': '₹ 4,35,000 / yr',
        'monthly': 36250.0,
        'avatar': 'https://lh3.googleusercontent.com/aida-public/AB6AXuB-CmFVB74qz2wo8Pnv3VVWdSXzh7qvzwScov8TGB4sP-rEO91Z-3_74bML5Rki9jgge3-os_7AGEeW9UzQ0_vGDf_Rr2eR3xibd2mClJZtFojgfq9XOYTe8FHR22mIgJwxB2fGXypnFNnneszuB33bbyeKtSuD_j5aiLrjBVeCN4y4gn7THpd7VBpMI21Gr2lOJgvyz2EX3IXBSUyCS0JypjTNqaSk3v4Rz-IgXk8kIF4q_wfrG5Bi',
        'selected': true,
      },
      {
        'name': 'Paul Williams',
        'role': 'Full-Time',
        'schedule': '40h/wk',
        'type': 'Regular',
        'since': 'Since Jul 1, 2026',
        'annual': '₹ 3,95,000 / yr',
        'monthly': 32916.0,
        'avatar': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCXFZQK_3JtEPuQHcWfe_4pEH7WmLJ9D46v_ehup8aDQ85Kb3dpc2CMGbLiZONX8CCsU3D1HiAbpOwe12OfTXt22dj9-dgCCbNaQ345e7LSK9ZOHGvuZN52jiaEaoiS4BYJ33CYOZDuzcJ9wf6B9_fN7NKnmEu1ou_13bmu4ZUpajfXf9fwfXJAZMrs8AHz_j5b0ONCI-WS_-wqAJGZFX06CdplTy0pXEiRGrgCdvfMvtCyKTnuRS_Z',
        'selected': true,
      },
      {
        'name': 'Aarav Mehta',
        'role': 'Payroll Specialist',
        'schedule': '40h/wk',
        'type': 'Regular',
        'since': 'Since Jan 1, 2026',
        'annual': '₹ 85,000 / mo',
        'monthly': 85000.0,
        'avatar': 'https://lh3.googleusercontent.com/aida-public/AB6AXuD59fCLV965z2Mt5ZSCKfVirq03pUJ5AkwyK_wiN7wJjDMWHgGkoI4B6_4GzAwM7woG9Sq28WtnzrKg0T7w7ZgNvx32K64eH8V00UxO_n02IIhOf-bAL2nd9_LaWjjkS_loR82IgnXVENSANhVHi0tXEJMumkRiBx1YlZ67_Nv3odoRlD16cCL4hpMIGHqAg171axg97Xiv1_qDb1xs-Jor62CqdRBVfnv1MVk1GTARhnk2pA6Nk07Z',
        'selected': true,
      },
    ];
  }

  int get _selectedCount => _employees.where((e) => e['selected'] == true).length;

  double get _estimatedGross {
    final ratio = _employees.isEmpty ? 0.0 : _selectedCount / _employees.length;
    return 1840000.0 * ratio;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _employees.where((e) {
      final name = (e['name'] as String).toLowerCase();
      final role = (e['role'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || role.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle & Pull Bar
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1C3CA),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF57344F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Color(0xFF57344F), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payrun Creation Wizard',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                        ),
                        Text(
                          'Batch Payroll Execution Engine',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF4E444A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Stepper Indicator & Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF2F3FF),
            child: Column(
              children: [
                Row(
                  children: [
                    // Step 1
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF57344F),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Text('Scope', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF57344F))),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00696E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Step 2
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00696E),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '2',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Employees', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00696E))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEDFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeStep = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: _activeStep == 0 ? const Color(0xFF92EFF5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.task_alt, size: 14, color: Color(0xFF57344F)),
                                const SizedBox(width: 5),
                                Text(
                                  '1. Define Scope',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeStep = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: _activeStep == 1 ? const Color(0xFF92EFF5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.group_add, size: 14, color: Color(0xFF00696E)),
                                const SizedBox(width: 5),
                                Text(
                                  '2. Select Employees',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF006E73)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Scrollable Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scope Locked Summary Capsule
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
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
                                const Icon(Icons.verified, size: 16, color: Color(0xFF57344F)),
                                const SizedBox(width: 6),
                                Text(
                                  'Configured Payroll Scope',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF57344F).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'LOCKED',
                                style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF57344F)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Jurisdiction & Cycle', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF4E444A))),
                                  Text('India: Regular Salary', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Pay Period', style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF4E444A))),
                                  Text(
                                    '01-Sep-2026 → 30-Sep-2026',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF57344F)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF92EFF5).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 15, color: Color(0xFF00696E)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Reviewing Step 1. The official Payrun batch ledger will only commit to accounting once employee validation is finalized below.',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF006E73), height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Employee Records', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('22 Employees eligible for September 2026 cycle', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF00696E))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF92EFF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '100% Eligible',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF006E73)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Search Field
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF4E444A)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel, size: 16, color: Color(0xFF4E444A)),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        hintText: 'Filter eligible employees by name or role...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF80747A)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Select All Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E7FF).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _selectedCount == _employees.length,
                                activeColor: const Color(0xFF57344F),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() {
                                    for (var e in _employees) {
                                      e['selected'] = val ?? false;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Select All ($_selectedCount/22)',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                          child: Text('All Active', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF4E444A))),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Employee Cards
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final emp = filtered[index];
                      return _buildEmployeeCard(emp);
                    },
                  ),

                  const SizedBox(height: 10),

                  // + 16 other employees indicator
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEDFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.groups, size: 16, color: Color(0xFF00696E)),
                        const SizedBox(width: 8),
                        Text(
                          '+ 16 other employees pre-validated for batch processing',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF4E444A)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // padding for sticky bottom
                ],
              ),
            ),
          ),

          // Sticky Bottom Summary Bar & Action Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
                        Text('$_selectedCount Employees Selected', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Est. Gross Payout', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF4E444A))),
                        Text(
                          '₹ ${_estimatedGross.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => setState(() => _activeStep = 0),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: Text('Scope', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 8,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCreated ? const Color(0xFF006443) : const Color(0xFF00696E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isGenerating
                            ? null
                            : () {
                                final navigator = Navigator.of(context);
                                setState(() => _isGenerating = true);
                                Future.delayed(const Duration(milliseconds: 900), () {
                                  if (mounted) {
                                    setState(() {
                                      _isGenerating = false;
                                      _isCreated = true;
                                    });
                                    widget.onBatchCreated?.call();
                                    Future.delayed(const Duration(milliseconds: 600), () {
                                      if (mounted) {
                                        navigator.pop();
                                      }
                                    });
                                  }
                                });
                              },
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(_isCreated ? Icons.done_all : Icons.check_circle, size: 18),
                        label: Text(
                          _isGenerating
                              ? 'Generating Batch...'
                              : _isCreated
                                  ? 'Batch Run Created!'
                                  : 'Create Payrun Batch',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final isSel = emp['selected'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: isSel,
                  activeColor: const Color(0xFF57344F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => setState(() => emp['selected'] = val ?? false),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  emp['avatar'],
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 42,
                    height: 42,
                    color: const Color(0xFFFFD7F1),
                    child: Center(
                      child: Text((emp['name'] as String)[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              emp['name'],
                              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                            ),
                            if (emp['isNew'] == true) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFFFFD7F1), borderRadius: BorderRadius.circular(4)),
                                child: Text('NEW', style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF2F1029))),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: emp['type'] == 'Prorated' ? const Color(0xFF57344F).withValues(alpha: 0.15) : const Color(0xFF00696E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            emp['type'],
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: emp['type'] == 'Prorated' ? const Color(0xFF57344F) : const Color(0xFF00696E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${emp['schedule']} • ${emp['role']}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF2F3FF).withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  emp['since'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: emp['since'].contains('Joined') ? const Color(0xFF57344F) : const Color(0xFF4E444A),
                    fontWeight: emp['since'].contains('Joined') ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  emp['annual'],
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: emp['annual'].contains('/ mo') ? const Color(0xFF00696E) : const Color(0xFF131B2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
