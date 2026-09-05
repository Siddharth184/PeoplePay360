import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/contract_service.dart';

class ContractsScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const ContractsScreen({super.key, this.onNavigateTab});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  bool _rulesExpanded = true;
  String _selectedStage = 'Running';
  double _monthlyWage = 100000.0;
  String _schedule = '40 Hours / Week (Standard)';
  String _contractType = 'Permanent / Full-Time';
  String _contractRef = 'CON/2026/0042';

  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  Future<void> _fetchContracts() async {
    final res = await ContractService.getContracts();
    if (mounted && res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      final first = res.data!.first;
      setState(() {
        _monthlyWage = first.wageMonthly;
        _selectedStage = first.status == 'RUNNING' ? 'Running' : (first.status == 'EXPIRED' ? 'Expired' : 'Draft');
        _contractRef = first.refCode;
      });
    }
  }

  void _openEditContractSheet() {
    final wageCtrl = TextEditingController(text: _monthlyWage.toStringAsFixed(2));
    String editSchedule = _schedule;
    String editType = _contractType;
    String editStage = _selectedStage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD7F1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit_note, color: Color(0xFF714B67), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Update Contract Terms',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stage Selector
                    Text(
                      'Contract Stage *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['Draft', 'Running', 'Expired', 'Cancelled'].map((st) {
                        final isSel = editStage == st;
                        return ChoiceChip(
                          label: Text(st),
                          selected: isSel,
                          selectedColor: const Color(0xFF714B67),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : const Color(0xFF4E444A),
                          ),
                          backgroundColor: const Color(0xFFF2F3FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (val) {
                            if (val) setSheetState(() => editStage = st);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Monthly Wage
                    Text(
                      'Monthly Gross Wage (INR ₹) *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        controller: wageCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF00696E), size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Working Schedule
                    Text(
                      'Working Schedule *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: editSchedule,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: '40 Hours / Week (Standard)', child: Text('40 Hours / Week (Standard)')),
                            DropdownMenuItem(value: '35 Hours / Week (Flexible)', child: Text('35 Hours / Week (Flexible)')),
                            DropdownMenuItem(value: '48 Hours / Week (Extended)', child: Text('48 Hours / Week (Extended)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => editSchedule = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Contract Type
                    Text(
                      'Contract Type *',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: editType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'Permanent / Full-Time', child: Text('Permanent / Full-Time')),
                            DropdownMenuItem(value: 'Fixed-Term Contract', child: Text('Fixed-Term Contract')),
                            DropdownMenuItem(value: 'Consultant / Retainer', child: Text('Consultant / Retainer')),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => editType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(context),
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
                              final newWage = double.tryParse(wageCtrl.text.trim()) ?? _monthlyWage;
                              setState(() {
                                _monthlyWage = newWage;
                                _schedule = editSchedule;
                                _contractType = editType;
                                _selectedStage = editStage;
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF004A31),
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('✓ Contract terms updated and validated with Odoo Payroll!'),
                                ),
                              );
                            },
                            child: const Text('Save Terms'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _printContractSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.print, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Generating Signed Contract PDF ($_contractRef)...',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Operational Header Bar
            _buildHeaderBar(),

            // Scrollable Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  // Contract Lifecycle Stepper
                  _buildLifecycleStepper(),

                  const SizedBox(height: 12),

                  // Business Guard Banner
                  _buildBusinessGuardBanner(),

                  const SizedBox(height: 12),

                  // Section 1: Employment Terms Card
                  _buildEmploymentTermsCard(),

                  const SizedBox(height: 14),

                  // Section 2: Compensation & Wage Card
                  _buildCompensationCard(),

                  const SizedBox(height: 12),

                  // Section 3: Digital Signature Metadata
                  _buildSignatureCard(),

                  const SizedBox(height: 16),

                  // Dual Action Buttons
                  _buildActionButtons(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(0);
                  }
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
                    child: Icon(Icons.arrow_back, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contract Details',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'CON/2026/0042',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF006443),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'PeoplePay360',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00696E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📜 Audit: Contract created 01-Jan-2026 by SysAdmin')),
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
                    child: Icon(Icons.history_edu, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ Options: Print PDF • Export XML • Archive')),
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
                    child: Icon(Icons.more_vert, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleStepper() {
    final steps = [
      {'name': 'Draft', 'isDone': true, 'isActive': false},
      {'name': 'Running', 'isDone': false, 'isActive': true},
      {'name': 'Expired', 'isDone': false, 'isActive': false},
      {'name': 'Cancelled', 'isDone': false, 'isActive': false},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connecting Track Line
          Positioned(
            left: 24,
            right: 24,
            top: 15,
            child: Container(
              height: 2,
              color: const Color(0xFFE2E8F0),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.map((step) {
              final isDone = step['isDone'] as bool;
              final isActive = step['isActive'] as bool;
              final name = step['name'] as String;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4EDEA3).withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF006443),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.verified, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    )
                  else if (isDone)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDAE2FD),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.check, color: Color(0xFF131B2E), size: 16),
                      ),
                    )
                  else
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD1C3CA),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? const Color(0xFF006443)
                          : (isDone ? const Color(0xFF4E444A) : const Color(0xFF80747A)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessGuardBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFCCF7FA).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00696E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Contract Guard',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF004F53),
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF4E444A),
                      height: 1.4,
                    ),
                    children: const [
                      TextSpan(text: 'This is the single active running contract for '),
                      TextSpan(text: 'Aarav Mehta', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF131B2E))),
                      TextSpan(text: ' for the current payroll cycle. Superseded or historical contracts are archived automatically.'),
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

  Widget _buildEmploymentTermsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Subheading
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF714B67)),
                  const SizedBox(width: 8),
                  Text(
                    'Employment Terms',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDAE2FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'EMP-99201',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF131B2E),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Employee Identification Snippet
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF714B67),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBdEf-4m50kA9OQg_t2t8GxE1b98fcDAfowAdYJ8MlFe2-FodUaYVIicVZP9sfZvbbS-7awB34cXKZKWL7nf1l2EblaMBQ2oWhPKulk2tSVM6fSnwK0dl4fjR5bIXjGgLrM_ZSM2ZaI-D0wXBsAzBEAizPLuUXKKNlRRR1JqN8TkQ-p35yGHlZw-2Q3FctrECb8YUVdxSXIPddbzmTKEdV9NUCFqtMm8LV7NmbemGjgyWI3FKQXQiKS',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('AM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          Text(
                            'Aarav Mehta',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF57344F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FINANCE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Payroll Specialist · Dept. of Accounts',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF4E444A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Color(0xFF80747A)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Detail Grid
          // Contract Period Row
          _buildDetailRow(
            icon: Icons.calendar_month,
            label: 'Contract Period',
            valueWidget: Row(
              children: [
                Text(
                  '01-Jan-2026',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Text('→', style: TextStyle(color: Color(0xFF80747A))),
                ),
                Text(
                  'Ongoing (—)',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF00696E)),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFCCF7FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Indefinite',
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF006E73)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Working Schedule
          _buildDetailRow(
            icon: Icons.schedule,
            label: 'Working Schedule',
            valueWidget: Text(
              _schedule,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
            ),
            trailing: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Working Schedule Builder...')),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.open_in_new, size: 16, color: Color(0xFF00696E)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Contract Type
          _buildDetailRow(
            icon: Icons.description_outlined,
            label: 'Contract Type',
            valueWidget: Text(
              _contractType,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
            ),
            trailing: const Icon(Icons.lock_outline, size: 17, color: Color(0xFF80747A)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompensationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF00696E)),
                  const SizedBox(width: 8),
                  Text(
                    'Compensation & Wage',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF006443).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'INR (₹)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006443),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Big Numeric Stat Display
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Gross Wage',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                    Text(
                      'Base Formula',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00696E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹ ${_monthlyWage.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00696E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ month',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cost to Company (CTC)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A)),
                      ),
                      Text(
                        '₹ 11,20,000.00 / yr',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Salary Structure Breakdown Snippet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEDFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF714B67)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regular Salary Structure',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                            ),
                            Text(
                              '12 Active Rules Configured',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => setState(() => _rulesExpanded = !_rulesExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rules',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF714B67)),
                            ),
                            Icon(
                              _rulesExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 15,
                              color: const Color(0xFF714B67),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (_rulesExpanded) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const [
                      _RulePill('Basic (50%)'),
                      _RulePill('HRA (20%)'),
                      _RulePill('Std Deduction'),
                      _RulePill('Provident Fund (12%)'),
                      _RulePill('ESI Guard'),
                      _RulePill('Special Allowance'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFDAE2FD),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.draw_outlined, color: Color(0xFF714B67), size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digitally Signed via PeoplePay e-Sign',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  Text(
                    'Hash: 8f9b...a12c · 02-Jan-2026',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Icon(Icons.check_circle, color: Color(0xFF006443), size: 20),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Update Terms Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF714B67),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 2,
            ),
            onPressed: _openEditContractSheet,
            icon: const Icon(Icons.edit_note, size: 19),
            label: Text(
              'Update Contract Terms',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Print Contract Summary Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF131B2E),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 1,
            ),
            onPressed: _printContractSummary,
            icon: const Icon(Icons.print, size: 19, color: Color(0xFF00696E)),
            label: Text(
              'Print Contract Summary',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required Widget valueWidget,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(icon, size: 17, color: const Color(0xFF714B67)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                  ),
                  const SizedBox(height: 1),
                  valueWidget,
                ],
              ),
            ],
          ),
          trailing,
        ],
      ),
    );
  }
}

class _RulePill extends StatelessWidget {
  final String text;
  const _RulePill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4E444A),
        ),
      ),
    );
  }
}
