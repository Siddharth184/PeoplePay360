import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimeOffSetupScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const TimeOffSetupScreen({super.key, this.onNavigateTab});

  @override
  State<TimeOffSetupScreen> createState() => _TimeOffSetupScreenState();
}

class _TimeOffSetupScreenState extends State<TimeOffSetupScreen> with SingleTickerProviderStateMixin {
  String _selectedDept = 'All Employees';
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _allocations = [
    {
      'id': 'aarav',
      'name': 'Aarav Mehta',
      'empId': 'EMP-4092',
      'initials': 'AM',
      'avatarBg': const Color(0xFF714B67),
      'avatarFg': Colors.white,
      'dept': 'Finance',
      'policy': 'Standard Annual Leave (2026)',
      'taken': 8.0,
      'remaining': 12.0,
      'allocated': 20.0,
      'takenPercent': 40,
      'remainingPercent': 60,
      'validUntil': 'Dec 31, 2026',
      'cap': '5d',
      'approver': 'Approved by Sara Khan (HR Lead)',
      'accrualRate': '+1.67 d/mo',
      'hasUrgency': false,
    },
    {
      'id': 'sara',
      'name': 'Sara Khan',
      'empId': 'EMP-4091',
      'initials': 'SK',
      'avatarBg': const Color(0xFF00696E),
      'avatarFg': Colors.white,
      'dept': 'Finance',
      'role': 'VP Finance & HR',
      'policy': 'Standard Annual Leave',
      'taken': 4.0,
      'remaining': 14.0,
      'allocated': 18.0,
      'takenPercent': 22,
      'remainingPercent': 78,
      'validUntil': 'Dec 31, 2026',
      'approver': 'Approved by Alex Morgan (SysAdmin)',
      'hasUrgency': false,
    },
    {
      'id': 'neha',
      'name': 'Neha Patel',
      'empId': 'EMP-4105',
      'initials': 'NP',
      'avatarBg': const Color(0xFFFFD7F1),
      'avatarFg': const Color(0xFF57344F),
      'dept': 'Finance',
      'role': 'Accounts Associate',
      'policy': 'Compensatory Off',
      'taken': 1.0,
      'remaining': 1.0,
      'allocated': 2.0,
      'takenPercent': 50,
      'remainingPercent': 50,
      'validUntil': 'Valid until Oct 31, 2026',
      'urgencyText': '58d left',
      'hasUrgency': true,
      'approver': 'Sara Khan approved',
    },
    {
      'id': 'rohan',
      'name': 'Rohan Patel',
      'empId': 'EMP-4076',
      'initials': 'RP',
      'avatarBg': const Color(0xFFDAE2FD),
      'avatarFg': const Color(0xFF131B2E),
      'dept': 'Engineering',
      'role': 'Engineering',
      'policy': 'Sick / Medical Leave',
      'taken': 2.0,
      'remaining': 10.0,
      'allocated': 12.0,
      'takenPercent': 16.7,
      'remainingPercent': 83.3,
      'validUntil': 'Valid Dec 31, 2026',
      'certNote': 'Medical cert. verified',
      'hasUrgency': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openAllocateSheet() {
    final daysCtrl = TextEditingController(text: '5.0');
    String selectedEmp = 'Aarav Mehta (EMP-4092)';
    String selectedPolicy = 'Standard Annual Leave (2026)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF92EFF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_circle, color: Color(0xFF006E73), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Allocate Leave Days',
                        style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Employee Selector
              Text('Beneficiary Employee *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedEmp,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Aarav Mehta (EMP-4092)', child: Text('Aarav Mehta (EMP-4092) — Finance')),
                      DropdownMenuItem(value: 'Sara Khan (EMP-4091)', child: Text('Sara Khan (EMP-4091) — VP HR')),
                      DropdownMenuItem(value: 'Neha Patel (EMP-4105)', child: Text('Neha Patel (EMP-4105) — Accounts')),
                      DropdownMenuItem(value: 'Rohan Patel (EMP-4076)', child: Text('Rohan Patel (EMP-4076) — Eng')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedEmp = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Policy Selector
              Text('Leave Allocation Policy *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedPolicy,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Standard Annual Leave (2026)', child: Text('Standard Annual Leave (2026)')),
                      DropdownMenuItem(value: 'Compensatory Off Credit', child: Text('Compensatory Off Credit')),
                      DropdownMenuItem(value: 'Special Medical Quota', child: Text('Special Medical Quota')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedPolicy = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Days count
              Text('Days to Allocate *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                height: 46,
                decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.pin, color: Color(0xFF00696E), size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF714B67),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final addDays = double.tryParse(daysCtrl.text.trim()) ?? 5.0;
                        setState(() {
                          final aarav = _allocations.firstWhere((a) => a['id'] == 'aarav');
                          aarav['allocated'] = (aarav['allocated'] as double) + addDays;
                          aarav['remaining'] = (aarav['remaining'] as double) + addDays;
                          final total = aarav['allocated'] as double;
                          final taken = aarav['taken'] as double;
                          aarav['takenPercent'] = ((taken / total) * 100).round();
                          aarav['remainingPercent'] = 100 - (aarav['takenPercent'] as int);
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF006443),
                            behavior: SnackBarBehavior.floating,
                            content: Text('✓ Successfully allocated +$addDays days to Aarav Mehta with Odoo 18 engine!'),
                          ),
                        );
                      },
                      child: const Text('Confirm Allocation'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportLedger() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        content: Text('📄 Exporting Leave Allocation Ledger (CSV & PDF ready for OXP ERP)...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _allocations.where((a) {
      if (_selectedDept == 'All Employees') return true;
      return a['dept'] == _selectedDept;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Policy Cycle & Auto-Accrual Status Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else if (widget.onNavigateTab != null) {
                                    widget.onNavigateTab!(-1);
                                  }
                                },
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F3FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.arrow_back, size: 16, color: Color(0xFF131B2E)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('📅 Selected: Annual Fiscal Cycle (Jan 1 – Dec 31, 2026)')),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.event_repeat, size: 16, color: Color(0xFF714B67)),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            'Cycle: FY 2026',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF131B2E),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.expand_more, size: 16, color: Color(0xFF4E444A)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Accrual Active Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF92EFF5).withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) => Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF00696E).withValues(alpha: 0.4 + 0.6 * _pulseController.value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'ACCRUAL ACTIVE',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                  color: const Color(0xFF004F53),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Screen Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Leave Allocations',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                              Text(
                                'Year 2026 • Policy Balances & Accrual Engine',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: const Color(0xFF4E444A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚡ Filter Matrix: Showing all 42 employees across 4 policies')),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF2F3FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.tune, size: 18, color: Color(0xFF131B2E)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Department Segment Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDeptChip('All Employees', 42),
                          const SizedBox(width: 8),
                          _buildDeptChip('Finance', 12),
                          const SizedBox(width: 8),
                          _buildDeptChip('Engineering', 18),
                          const SizedBox(width: 8),
                          _buildDeptChip('Operations', 12),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Summary KPI Ribbon
                    Row(
                      children: [
                        _buildSummaryCard('Allocated', '420', 'Days', 1.0, const Color(0xFF714B67)),
                        const SizedBox(width: 8),
                        _buildSummaryCard('Utilized', '148', '35.2%', 0.352, const Color(0xFF79526F)),
                        const SizedBox(width: 8),
                        _buildSummaryCard('Available', '272', '64.8%', 0.648, const Color(0xFF00696E), isHighlighted: true),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Allocation Cards List
                    Column(
                      children: filteredList.map((alloc) => _buildAllocationCard(alloc)).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action & Audit Strip (Level 3 Glass Float)
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeptChip(String name, int count) {
    final isSel = _selectedDept == name;

    return InkWell(
      onTap: () => setState(() => _selectedDept = name),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF714B67) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSel ? null : Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: isSel
              ? [
                  BoxShadow(
                    color: const Color(0xFF714B67).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? Colors.white : const Color(0xFF4E444A),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSel ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.white : const Color(0xFF131B2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, String subtext, double progress, Color color, {bool isHighlighted = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFF92EFF5).withValues(alpha: 0.25) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isHighlighted ? const Color(0xFF92EFF5) : const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isHighlighted ? const Color(0xFF004F53) : const Color(0xFF4E444A),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  count,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? const Color(0xFF00696E) : const Color(0xFF131B2E),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  subtext,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                    color: isHighlighted ? const Color(0xFF00696E) : const Color(0xFF4E444A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationCard(Map<String, dynamic> alloc) {
    final taken = alloc['taken'] as double;
    final remaining = alloc['remaining'] as double;
    final allocated = alloc['allocated'] as double;
    final takenPercent = alloc['takenPercent'] as num;
    final remainingPercent = alloc['remainingPercent'] as num;
    final hasUrgency = alloc['hasUrgency'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: alloc['avatarBg'] as Color,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  alloc['initials'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: alloc['avatarFg'] as Color,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF78D5DB),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  alloc['name'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF131B2E),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDAE2FD),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    alloc['empId'] as String,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF131B2E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  alloc['role'] ?? alloc['dept'] as String,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF4E444A)),
                                ),
                                const SizedBox(width: 4),
                                Text('•', style: TextStyle(color: Colors.grey[400])),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    alloc['policy'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF57344F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (hasUrgency)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDAD6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 13, color: Color(0xFFBA1A1A)),
                            const SizedBox(width: 3),
                            Text(
                              alloc['urgencyText'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFBA1A1A),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF4E444A)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Options for ${alloc['name']} (Edit Allocation / Export / Revoke)')),
                          );
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Segmented Bicolor Meter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF79526F), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                          '${taken.toStringAsFixed(1)} Days Taken ($takenPercent%)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF79526F)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF00696E), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                          '${remaining.toStringAsFixed(1)} Days Left ($remainingPercent%)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Meter Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (takenPercent * 10).round(),
                          child: Container(color: const Color(0xFF79526F)),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: (remainingPercent * 10).round(),
                          child: Container(color: const Color(0xFF00696E)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Math Equation Grid
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Allocated
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'ALLOCATED',
                                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF4E444A)),
                              ),
                              Text(
                                '${allocated.toStringAsFixed(1)} D',
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('=', style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF80747A))),
                      ),
                      // Taken
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'TAKEN',
                                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF79526F)),
                              ),
                              Text(
                                '${taken.toStringAsFixed(1)} D',
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF79526F)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('+', style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF80747A))),
                      ),
                      // Remaining
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF92EFF5).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'REMAINING',
                                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF004F53)),
                              ),
                              Text(
                                '${remaining.toStringAsFixed(1)} D',
                                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footnote Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF).withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasUrgency ? Icons.warning_amber_rounded : Icons.verified_outlined,
                      size: 15,
                      color: hasUrgency ? const Color(0xFFBA1A1A) : const Color(0xFF006443),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      alloc['approver'] ?? alloc['certNote'] ?? 'Approved',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hasUrgency ? const Color(0xFFBA1A1A) : const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
                Text(
                  alloc['validUntil'] as String,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF4E444A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF714B67),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 2,
                    ),
                    onPressed: _openAllocateSheet,
                    icon: const Icon(Icons.add_circle_outline, size: 19),
                    label: Text(
                      '+ Allocate Days',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _exportLedger,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E7FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Icon(Icons.download, color: Color(0xFF131B2E), size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync, size: 14, color: Color(0xFF00696E)),
                  const SizedBox(width: 4),
                  Text(
                    'Odoo 18 Engine • Live Sync',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF4E444A)),
                  ),
                ],
              ),
              InkWell(
                onTap: _exportLedger,
                child: Row(
                  children: [
                    Text(
                      'Ledger (CSV / PDF)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF714B67),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF714B67)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
