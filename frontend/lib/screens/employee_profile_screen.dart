import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/employee_service.dart';
import '../services/mock_data_service.dart';
import '../widgets/payslip_pdf_dialog.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final EmployeeModel? initialEmployee;
  const EmployeeProfileScreen({super.key, this.onNavigateTab, this.initialEmployee});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  int _selectedTabIndex = 0;
  late EmployeeModel emp;

  @override
  void initState() {
    super.initState();
    emp = widget.initialEmployee ?? MockDataService.currentEmployee;
    EmployeeService.currentEmployeeNotifier.addListener(_onEmployeeNotifierChanged);
    _refreshProfile();
  }

  @override
  void didUpdateWidget(EmployeeProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEmployee != null && widget.initialEmployee != oldWidget.initialEmployee) {
      setState(() {
        emp = widget.initialEmployee!;
      });
    }
  }

  void _onEmployeeNotifierChanged() {
    if (mounted) {
      final updated = EmployeeService.currentEmployeeNotifier.value;
      if (updated.id == emp.id || widget.initialEmployee == null) {
        setState(() {
          emp = updated;
        });
      }
    }
  }

  @override
  void dispose() {
    EmployeeService.currentEmployeeNotifier.removeListener(_onEmployeeNotifierChanged);
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final res = await EmployeeService.getEmployee(emp.id);
    if (mounted && res.isSuccess && res.data != null) {
      setState(() {
        emp = res.data!;
      });
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color iconColor = const Color(0xFF714B67)}) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF131B2E),
            ),
          ),
        ],
      ),
    );
  }

  void _onProfileAction(String action) {
    switch (action) {
      case 'edit':
        _openEditEmployeeSheet();
        break;
      case 'copy_email':
        Clipboard.setData(ClipboardData(text: emp.email));
        _toast('Work email copied to clipboard');
        break;
      case 'copy_id':
        Clipboard.setData(ClipboardData(text: emp.badgeId ?? emp.id));
        _toast('Employee ID copied to clipboard');
        break;
      case 'print_payslip':
        if (MockDataService.payslips.isNotEmpty) {
          showDialog(
            context: context,
            builder: (context) => PayslipPdfDialog(payslip: MockDataService.payslips.first),
          );
        } else {
          _toast('No payslip available to print yet');
        }
        break;
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openEditEmployeeSheet() {
    final nameCtrl = TextEditingController(text: emp.name);
    final titleCtrl = TextEditingController(text: emp.jobTitle);
    final deptCtrl = TextEditingController(text: emp.department);
    final emailCtrl = TextEditingController(text: emp.email);
    final phoneCtrl = TextEditingController(text: emp.workPhone);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
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
                              Expanded(
                                child: Text(
                                  'Edit Employee Profile',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF131B2E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF4E444A)),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFormField('Full Name', nameCtrl),
                    const SizedBox(height: 12),
                    _buildFormField('Job Position / Title', titleCtrl),
                    const SizedBox(height: 12),
                    _buildFormField('Department', deptCtrl),
                    const SizedBox(height: 12),
                    _buildFormField('Work Email', emailCtrl),
                    const SizedBox(height: 12),
                    _buildFormField('Work Phone', phoneCtrl),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(sheetContext),
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
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setSheetState(() => isSaving = true);
                                    final updatedName = nameCtrl.text.trim();
                                    final updatedTitle = titleCtrl.text.trim();
                                    final updatedDept = deptCtrl.text.trim();
                                    final updatedEmail = emailCtrl.text.trim();
                                    final updatedPhone = phoneCtrl.text.trim();

                                    final payload = {
                                      'name': updatedName.isNotEmpty ? updatedName : emp.name,
                                      'job_position_name': updatedTitle.isNotEmpty ? updatedTitle : emp.jobTitle,
                                      'job_position': updatedTitle.isNotEmpty ? updatedTitle : emp.jobTitle,
                                      'department_name': updatedDept.isNotEmpty ? updatedDept : emp.department,
                                      'department': updatedDept.isNotEmpty ? updatedDept : emp.department,
                                      'work_email': updatedEmail.isNotEmpty ? updatedEmail : emp.email,
                                      'phone': updatedPhone.isNotEmpty ? updatedPhone : emp.workPhone,
                                    };

                                    final messenger = ScaffoldMessenger.of(context);
                                    final res = await EmployeeService.updateEmployee(emp.id, payload);
                                    if (mounted) {
                                      setState(() {
                                        emp = res.data ?? emp.copyWith(
                                          name: payload['name'],
                                          jobTitle: payload['job_position_name'],
                                          department: payload['department_name'],
                                          email: payload['work_email'],
                                          workPhone: payload['phone'],
                                        );
                                      });
                                    }

                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }

                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF004A31),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          content: Text(
                                            '✓ Employee position updated to "${emp.jobTitle}" in Odoo Master Data',
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save Changes'),
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

  Widget _buildFormField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: ctrl,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF131B2E)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _openMessageSheet() {
    final msgCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            Text(
              'Send Internal Message to Aarav Mehta',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Message will be delivered to Odoo Enterprise Discuss channel.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A)),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Type your message or payroll note here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF714B67),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF004A31),
                      behavior: SnackBarBehavior.floating,
                      content: Text('✓ Message dispatched to Aarav Mehta on Odoo Discuss'),
                    ),
                  );
                },
                child: const Text('Send Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openManagerProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF714B67),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Sara Khan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Direct Manager • Executive Director', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('Department: Finance & Global Operations', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Email: sara.khan@oxp.com', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF00696E))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top Ambient Glass Header Strip
                _buildHeaderStrip(),

                // Scrollable Content with Pull-to-Refresh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshProfile,
                    color: const Color(0xFF714B67),
                    backgroundColor: Colors.white,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                      children: [
                        // Hero Identity Card
                        _buildHeroIdentityCard(),

                        const SizedBox(height: 18),

                        // Linked Operations Ribbon
                        _buildLinkedOperationsRibbon(),

                        const SizedBox(height: 18),

                        // Segmented Navigation Tabs
                        _buildSegmentedTabs(),

                        const SizedBox(height: 16),

                        // Active Tab Content
                        if (_selectedTabIndex == 0)
                          _buildWorkInfoTab()
                        else if (_selectedTabIndex == 1)
                          _buildPrivateInfoTab()
                        else
                          _buildPayrollTab(),

                        const SizedBox(height: 16),

                        // Weekly Activity Metric Summary Mini-Panel
                        _buildWeeklyActivityMiniPanel(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Floating Glass Action Bar
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildBottomActionBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStrip() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMPLOYEE MASTER 360',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: const Color(0xFF00696E),
                        ),
                      ),
                      Text(
                        emp.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
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
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F3FF),
              shape: BoxShape.circle,
            ),
            child: PopupMenuButton<String>(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF4E444A)),
              padding: EdgeInsets.zero,
              tooltip: 'Employee actions',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              onSelected: _onProfileAction,
              itemBuilder: (context) => [
                _menuItem('edit', Icons.edit_outlined, 'Edit Profile', iconColor: const Color(0xFF714B67)),
                _menuItem('copy_email', Icons.alternate_email_rounded, 'Copy Work Email', iconColor: const Color(0xFF00696E)),
                _menuItem('copy_id', Icons.badge_outlined, 'Copy Employee ID', iconColor: const Color(0xFF714B67)),
                _menuItem('print_payslip', Icons.receipt_long_rounded, 'Print Latest Payslip', iconColor: const Color(0xFF00696E)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroIdentityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with Live Pulse Status
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF714B67),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCbsoTZ0Vx9N04FD4eL7UQMy_-yAeybZT8_7RHikoeGs9c0SVRwpRjiGrGotFyDJ04pM2GKizqU9K7o224NaNtpnByX7QOUPjpqHkhoDENWwXg9qncIehOXYyq2mD99puGihph51lABkPxJ7-nLZQUnVhtnMiWcUxndCHpKSifBjAXMvmNNO8h-674VvcYIBj2MgK1P_Mgi8FE8gH7JexHEFPQ_cTnvwt-zbEJHQBXOBEgVMYX01mSY',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            'AM',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF006443),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Main Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          emp.name,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006443),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'EMP-4092',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${emp.jobTitle} • ${emp.department}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tags row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E7FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00696E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Full-time Regular',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF92EFF5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Level 3',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF006E73),
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

          const SizedBox(height: 14),

          // Quick Contact Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mail_outline, color: Color(0xFF00696E), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      emp.email,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF131B2E)),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📋 Copied ${emp.email} to clipboard')),
                    );
                  },
                  child: const Icon(Icons.content_copy, size: 15, color: Color(0xFF80747A)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: Color(0xFF00696E), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      emp.workPhone,
                      style: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: const Color(0xFF131B2E)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00696E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    elevation: 0,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📞 Dialing ${emp.workPhone}...')),
                    );
                  },
                  icon: const Icon(Icons.call, size: 13),
                  label: Text('Call', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedOperationsRibbon() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LINKED OPERATIONS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: const Color(0xFF4E444A),
              ),
            ),
            Text(
              'Auto-Synced',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00696E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Smart Button 1: Time Off
              _buildSmartButton(
                bgColor: const Color(0xFF92EFF5),
                textColor: const Color(0xFF006E73),
                icon: Icons.confirmation_number_outlined,
                metric: '3 Requests',
                label: 'Time Off',
                onTap: () => widget.onNavigateTab?.call(2),
              ),
              const SizedBox(width: 8),
              // Smart Button 2: Contracts
              _buildSmartButton(
                bgColor: const Color(0xFF57344F),
                textColor: Colors.white,
                icon: Icons.description_outlined,
                metric: '2 (1 Active)',
                label: 'Contracts',
                onTap: () => widget.onNavigateTab?.call(3),
              ),
              const SizedBox(width: 8),
              // Smart Button 3: Attendance
              _buildSmartButton(
                bgColor: const Color(0xFFE2E7FF),
                textColor: const Color(0xFF131B2E),
                icon: Icons.schedule_outlined,
                metric: '14 Days',
                label: 'Attendance',
                onTap: () => widget.onNavigateTab?.call(1),
              ),
              const SizedBox(width: 8),
              // Smart Button 4: Allocations
              _buildSmartButton(
                bgColor: const Color(0xFF714B67),
                textColor: Colors.white,
                icon: Icons.donut_large_outlined,
                metric: '20 Days',
                label: 'Allocations',
                onTap: () => widget.onNavigateTab?.call(2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmartButton({
    required Color bgColor,
    required Color textColor,
    required IconData icon,
    required String metric,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(icon, color: textColor, size: 18),
                  ),
                ),
                Icon(Icons.arrow_forward, color: textColor.withValues(alpha: 0.7), size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              metric,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: textColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTabItem('Work Info', 0),
          _buildTabItem('Private Info', 1),
          _buildTabItem('Payroll', 2),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF131B2E) : const Color(0xFF4E444A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkInfoTab() {
    return Column(
      children: [
        // Active Status Ribbon Banner
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF006443),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Color(0xFF56E5A9), size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT EMPLOYMENT STATUS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: const Color(0xFF56E5A9),
                        ),
                      ),
                      Text(
                        'Active Employee',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF004A31),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'OXP/2024/09',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6FFBBE),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Work Organization Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Work Organization',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  Text(
                    'HR-REG-301',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: const Color(0xFF80747A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Department
              _buildOrgRow(
                icon: Icons.account_tree_outlined,
                iconColor: const Color(0xFF00696E),
                title: 'Department',
                value: emp.department,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCF7FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups, size: 13, color: Color(0xFF006E73)),
                      const SizedBox(width: 4),
                      Text(
                        'Team 04',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF006E73),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // Direct Manager
              _buildOrgRow(
                icon: Icons.supervisor_account_outlined,
                iconColor: const Color(0xFF714B67),
                title: 'Direct Manager',
                value: 'Sara Khan',
                trailing: InkWell(
                  onTap: _openManagerProfileDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 9,
                          backgroundColor: Color(0xFF714B67),
                          child: Text('SK', style: TextStyle(color: Colors.white, fontSize: 8)),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Profile',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF4E444A)),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 20),

              // Working Schedule
              _buildOrgRow(
                icon: Icons.calendar_today_outlined,
                iconColor: const Color(0xFF00696E),
                title: 'Working Schedule',
                value: '40 Hours / Week',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEDFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CON/SCHED-01',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.tune, size: 12, color: Color(0xFF131B2E)),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // Work Location
              _buildOrgRow(
                icon: Icons.corporate_fare_outlined,
                iconColor: const Color(0xFFBA1A1A),
                title: 'Work Location',
                value: 'Mumbai Head Office',
                subtitle: 'Building B, Floor 4 • Desk B-412',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Zone IN-1',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const Divider(height: 20),

              // Desk Extension
              _buildOrgRow(
                icon: Icons.desk_outlined,
                iconColor: const Color(0xFF00696E),
                title: 'Desk Extension',
                value: '+91 98765 43210',
                trailing: Text(
                  'Ext. #482',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF80747A)),
                ),
              ),

              const SizedBox(height: 14),

              // Odoo Linked System Account
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.manage_accounts_outlined, color: Color(0xFF714B67), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Odoo Linked System Account',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4E444A),
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.check_circle, color: Color(0xFF006443), size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'aarav@company.com',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                          Text(
                            'HR Payroll User • Automated Sync Active',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00696E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivateInfoTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Private Contact & Identity',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildOrgRow(icon: Icons.home_outlined, iconColor: const Color(0xFF714B67), title: 'Home Address', value: '402 Sunrise Heights, Andheri East, Mumbai 400069'),
          const Divider(height: 20),
          _buildOrgRow(icon: Icons.badge_outlined, iconColor: const Color(0xFF00696E), title: 'National ID / PAN', value: 'ABCDE1234F', trailing: const Text('Verified', style: TextStyle(color: Color(0xFF006443), fontWeight: FontWeight.bold, fontSize: 12))),
          const Divider(height: 20),
          _buildOrgRow(icon: Icons.account_balance_outlined, iconColor: const Color(0xFF714B67), title: 'Bank Account (Salary)', value: 'HDFC Bank • •••• 8829', trailing: const Text('IFSC: HDFC0001234', style: TextStyle(fontSize: 11, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildPayrollTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Salary Structure',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFCCF7FA), borderRadius: BorderRadius.circular(16)),
                child: Text('RULE-IND-REG-01', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF006E73))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOrgRow(icon: Icons.currency_rupee, iconColor: const Color(0xFF006443), title: 'Monthly Base Salary', value: '₹ 85,000.00 / Mo'),
          const Divider(height: 20),
          _buildOrgRow(icon: Icons.add_circle_outline, iconColor: const Color(0xFF00696E), title: 'Allowances (HRA + Special)', value: '₹ 28,500.00 / Mo'),
          const Divider(height: 20),
          _buildOrgRow(icon: Icons.remove_circle_outline, iconColor: const Color(0xFFBA1A1A), title: 'Statutory Deductions (PF + TDS)', value: '- ₹ 12,400.00 / Mo'),
          const Divider(height: 20),
          _buildOrgRow(icon: Icons.account_balance_wallet_outlined, iconColor: const Color(0xFF714B67), title: 'Estimated Net Monthly', value: '₹ 1,01,100.00', trailing: const Text('Gross: ₹ 1.13L', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF714B67)))),
        ],
      ),
    );
  }

  Widget _buildOrgRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF80747A),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildWeeklyActivityMiniPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.bar_chart, color: Color(0xFF714B67), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pay Cycle Accrual (Nov)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                  Text(
                    '158.5 / 168.0 Hrs',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Circular progress indicator (94%)
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CircularProgressIndicator(
                  value: 0.94,
                  strokeWidth: 4,
                  backgroundColor: Color(0xFFDAE2FD),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00696E)),
                ),
                Center(
                  child: Text(
                    '94%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // PDF Export Button
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => PayslipPdfDialog(payslip: MockDataService.payslips.first),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F3FF),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.picture_as_pdf, color: Color(0xFF131B2E), size: 19),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Message Button
          InkWell(
            onTap: _openMessageSheet,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F3FF),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.chat_outlined, color: Color(0xFF131B2E), size: 19),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Edit Employee Primary Button
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF714B67),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 2,
              ),
              onPressed: _openEditEmployeeSheet,
              icon: const Icon(Icons.edit_note, size: 18),
              label: Text(
                'Edit Employee',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
