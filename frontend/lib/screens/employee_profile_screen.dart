import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/employee_service.dart';
import '../services/mock_data_service.dart';
import '../services/payrun_service.dart';
import '../widgets/payslip_pdf_dialog.dart';
import 'contracts_screen.dart';

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

  String _selectedPayMonth = '2026-09-01 → 2026-09-30';
  String _selectedAttendanceMonth = '2026-09-01 → 2026-09-30';
  List<PayslipModel> _employeePayslips = [];
  bool _isLoadingPayslips = false;

  @override
  void initState() {
    super.initState();
    emp = widget.initialEmployee ??
        MockDataService.getEmployeeForUser(
          email: ApiClient.currentEmail,
          role: ApiClient.activeRole,
          name: ApiClient.currentEmployeeName,
        );
    EmployeeService.currentEmployeeNotifier.addListener(_onEmployeeNotifierChanged);
    _refreshProfile();
    _loadPayslipsForEmployee();
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

  Future<void> _loadPayslipsForEmployee() async {
    if (_isLoadingPayslips) return;
    setState(() => _isLoadingPayslips = true);
    final res = await PayrunService.getPayslips(employeeId: emp.id);
    if (mounted) {
      setState(() {
        _isLoadingPayslips = false;
        if (res.isSuccess && res.data != null) {
          _employeePayslips = res.data!.map((p) => p.copyWith(employeeName: emp.name)).toList();
        } else if (!ApiClient.isBackendOnline || res.statusCode == 0) {
          _employeePayslips = MockDataService.payslips.map((p) => p.copyWith(employeeName: emp.name)).toList();
        } else {
          _employeePayslips = [];
        }
      });
    }
  }

  PayslipModel _getActivePayslip() {
    final payslipList = _employeePayslips.isNotEmpty ? _employeePayslips : MockDataService.payslips;
    if (payslipList.isEmpty) {
      return PayslipModel(
        id: 'slip-draft',
        refCode: 'SLIP/DRAFT',
        employeeName: emp.name,
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        netAmount: 0.0,
        grossAmount: 0.0,
        status: 'DRAFT',
        lines: const [],
      );
    }

    final selStart = _selectedPayMonth.contains('→') ? _selectedPayMonth.split('→').first.trim() : _selectedPayMonth;

    PayslipModel? match;
    for (final p in payslipList) {
      if (p.periodStart == selStart || '${p.periodStart} → ${p.periodEnd}' == _selectedPayMonth) {
        match = p;
        break;
      }
      if (selStart.length >= 7 && p.periodStart.startsWith(selStart.substring(0, 7))) {
        match = p;
        break;
      }
    }

    if (match == null) {
      final lower = _selectedPayMonth.toLowerCase();
      if (lower.contains('aug') || lower.contains('2026-08')) {
        match = payslipList.firstWhere((p) => p.periodStart.startsWith('2026-08'), orElse: () => payslipList.first);
      } else if (lower.contains('jul') || lower.contains('2026-07')) {
        match = payslipList.firstWhere((p) => p.periodStart.startsWith('2026-07'), orElse: () => payslipList.first);
      } else if (lower.contains('jun') || lower.contains('2026-06')) {
        match = payslipList.firstWhere((p) => p.periodStart.startsWith('2026-06'), orElse: () => payslipList.first);
      } else if (lower.contains('may') || lower.contains('2026-05')) {
        match = payslipList.firstWhere((p) => p.periodStart.startsWith('2026-05'), orElse: () => payslipList.first);
      } else if (lower.contains('feb') || lower.contains('2026-02')) {
        match = payslipList.firstWhere((p) => p.periodStart.startsWith('2026-02'), orElse: () => payslipList.first);
      } else if (lower.contains('sep') || lower.contains('2026-09')) {
        match = payslipList.firstWhere((p) => p.periodStart.startsWith('2026-09'), orElse: () => payslipList.first);
      }
    }

    final selected = match ?? payslipList.first;
    return selected.copyWith(employeeName: emp.name);
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
      case 'contracts':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContractsScreen(
              onNavigateTab: widget.onNavigateTab,
              initialEmployee: emp,
            ),
          ),
        );
        break;
      case 'print_payslip':
        final activeSlip = _getActivePayslip();
        showDialog(
          context: context,
          builder: (context) => PayslipPdfDialog(payslip: activeSlip),
        );
        break;
      case 'send_message':
        _openMessageSheet();
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

  bool get _isOwnProfile {
    if (widget.initialEmployee == null) return true;
    if (ApiClient.isOwnProfile(emp.id)) return true;
    if (ApiClient.currentEmail != null && emp.email.toLowerCase() == ApiClient.currentEmail!.toLowerCase()) return true;
    return false;
  }

  bool get _canEdit => ApiClient.hasHrAccess && !_isOwnProfile;

  void _openEditEmployeeSheet() {
    if (!_canEdit) {
      _toast('Access restricted: You cannot edit your own profile.');
      return;
    }
    final nameCtrl = TextEditingController(text: emp.name);
    final titleCtrl = TextEditingController(text: emp.jobTitle);
    final deptCtrl = TextEditingController(text: emp.department);
    final emailCtrl = TextEditingController(text: emp.email);
    final phoneCtrl = TextEditingController(text: emp.workPhone);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
      useSafeArea: true,
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
            Text(
              'Send Internal Message to ${emp.name}',
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
                    SnackBar(
                      backgroundColor: const Color(0xFF004A31),
                      behavior: SnackBarBehavior.floating,
                      content: Text('✓ Message dispatched to ${emp.name} on Odoo Discuss'),
                    ),
                  );
                },
                child: const Text('Send Message'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _openManagerProfileDialog() {
    final manager = emp.managerName.isNotEmpty ? emp.managerName : 'Sara Khan';
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
            Flexible(
              child: Text(
                manager,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reporting Manager • Executive Lead', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('Department: ${emp.department}', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Status: Active in Hierarchy', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF00696E))),
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

                        // Linked Operations Ribbon (Commented out for HR view: bottom navbar already provides direct navigation to Attendance, Time Off, Contracts)
                        // _buildLinkedOperationsRibbon(),
                        // const SizedBox(height: 18),

                        // Segmented Navigation Tabs
                        _buildSegmentedTabs(),

                        const SizedBox(height: 16),

                        // Active Tab Content
                        if (_selectedTabIndex == 0)
                          _buildWorkInfoTab()
                        else if (_selectedTabIndex == 1)
                          _buildPrivateInfoTab()
                        else if (_selectedTabIndex == 2)
                          _buildAttendanceTab()
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
                      child: const Center(
                        child: Icon(Icons.arrow_back, size: 18, color: Color(0xFF131B2E)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
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
              itemBuilder: (context) {
                return [
                  _menuItem('contracts', Icons.description_outlined, 'Contracts', iconColor: const Color(0xFF714B67)),
                  _menuItem('print_payslip', Icons.receipt_long_rounded, 'Print Latest Payslip', iconColor: const Color(0xFF00696E)),
                  _menuItem('send_message', Icons.chat_outlined, 'Send Internal Message', iconColor: const Color(0xFF714B67)),
                ];
              },
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
                        Flexible(
                          child: Text(
                            emp.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
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
                            emp.badgeId ?? 'EMP-4092',
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline, color: Color(0xFF00696E), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          emp.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF131B2E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, color: Color(0xFF00696E), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          emp.workPhone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: const Color(0xFF131B2E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

  // ignore: unused_element
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildTabItem('Work Info', 0),
            _buildTabItem('Private Info', 1),
            _buildTabItem('Attendance', 2),
            _buildTabItem('Payroll', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                value: (emp.workLocation != null && emp.workLocation!.isNotEmpty) ? emp.workLocation! : 'Bengaluru HQ',
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

  Widget _buildAttendanceTab() {
    final availableAttendanceMonths = [
      '2026-09-01 → 2026-09-30',
      '2026-08-01 → 2026-08-31',
      '2026-07-01 → 2026-07-31',
      '2026-06-01 → 2026-06-30',
    ];

    if (!availableAttendanceMonths.contains(_selectedAttendanceMonth)) {
      _selectedAttendanceMonth = availableAttendanceMonths.first;
    }

    final selStart = _selectedAttendanceMonth.split('→').first.trim();
    final periodDate = DateTime.tryParse(selStart) ?? DateTime(2026, 9, 1);
    final yearMonthStr = DateFormat('yyyy-MM').format(periodDate);
    final monthTitle = DateFormat('MMMM yyyy').format(periodDate);

    // Fetch all attendance records for this employee
    final allUserAttendances = MockDataService.attendances.where((a) {
      if (a.employeeId == emp.id) return true;
      if (a.employeeName != null && a.employeeName!.isNotEmpty) {
        final firstName = emp.name.toLowerCase().split(' ').first;
        return a.employeeName!.toLowerCase().contains(firstName);
      }
      return false;
    }).toList();

    final monthAttendances = allUserAttendances.where((a) {
      if (a.checkIn != null) {
        return DateFormat('yyyy-MM').format(a.checkIn!) == yearMonthStr;
      }
      if (a.dateStr.length >= 7) {
        return a.dateStr.startsWith(yearMonthStr);
      }
      return false;
    }).toList();

    // Calculate Summary Metrics
    int presentCount = 0;
    int lateCount = 0;
    int leaveCount = 0;
    int absentCount = 0;
    double totalWorkedHours = 0.0;

    for (final att in monthAttendances) {
      final st = att.status.toUpperCase();
      totalWorkedHours += att.workedHours;
      if (st == 'PRESENT') {
        presentCount++;
      } else if (st == 'LATE' || st == 'HALF_DAY') {
        lateCount++;
      } else if (st == 'LEAVE' || st == 'PTO' || st == 'SICK') {
        leaveCount++;
      } else if (st == 'ABSENT') {
        absentCount++;
      } else {
        presentCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Selector Card
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
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF714B67)),
                      const SizedBox(width: 8),
                      Text(
                        'Select Attendance Month',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E7FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${monthAttendances.length} Logs',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD6DAFE)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedAttendanceMonth,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF714B67)),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                    items: availableAttendanceMonths.map((String m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_outlined, size: 16, color: Color(0xFF714B67)),
                            const SizedBox(width: 8),
                            Text(
                              m,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedAttendanceMonth = val;
                          _selectedPayMonth = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Color-coded Month Summary Stats Row
        Row(
          children: [
            // Present Badge (Green)
            Expanded(
              child: _buildAttendanceStatCard(
                label: 'Present',
                value: '$presentCount Days',
                subtext: '${totalWorkedHours.toStringAsFixed(1)} Hrs',
                bgColor: const Color(0xFFE8F5E9),
                borderColor: const Color(0xFFA5D6A7),
                textColor: const Color(0xFF006443),
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 8),
            // Late / Half Day Badge (Orange/Amber)
            Expanded(
              child: _buildAttendanceStatCard(
                label: 'Late / Half',
                value: '$lateCount Days',
                subtext: 'Shift Deviations',
                bgColor: const Color(0xFFFFF3E0),
                borderColor: const Color(0xFFFFCC80),
                textColor: const Color(0xFFE65100),
                icon: Icons.access_time_filled_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            // Leave / Time Off Badge (Purple)
            Expanded(
              child: _buildAttendanceStatCard(
                label: 'On Leave',
                value: '$leaveCount Days',
                subtext: 'Approved Time Off',
                bgColor: const Color(0xFFF2F3FF),
                borderColor: const Color(0xFFD6DAFE),
                textColor: const Color(0xFF714B67),
                icon: Icons.event_available_outlined,
              ),
            ),
            const SizedBox(width: 8),
            // Absent Badge (Red)
            Expanded(
              child: _buildAttendanceStatCard(
                label: 'Absent',
                value: '$absentCount Days',
                subtext: 'Unexcused',
                bgColor: const Color(0xFFFFDAD6),
                borderColor: const Color(0xFFFFB4AB),
                textColor: const Color(0xFFBA1A1A),
                icon: Icons.cancel_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Color-Coded Day-by-Day Ledger List Card
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
                  Expanded(
                    child: Text(
                      'Attendance Ledger ($monthTitle)',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${monthAttendances.length} Entries',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF80747A)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (monthAttendances.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.event_note_outlined, size: 36, color: Color(0xFF80747A)),
                      const SizedBox(height: 8),
                      Text(
                        'No Attendance Logs for $monthTitle',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF131B2E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Punch-in records and manual edits for this month will dynamically appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF80747A)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthAttendances.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final item = monthAttendances[index];
                    return _buildAttendanceRowItem(item);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStatCard({
    required String label,
    required String value,
    required String subtext,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: textColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.8)),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  subtext,
                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: textColor.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRowItem(AttendanceModel item) {
    Color badgeBg;
    Color badgeText;
    String statusLabel = item.status.toUpperCase();

    switch (statusLabel) {
      case 'PRESENT':
        badgeBg = const Color(0xFFE8F5E9);
        badgeText = const Color(0xFF006443);
        break;
      case 'LATE':
        badgeBg = const Color(0xFFFFF3E0);
        badgeText = const Color(0xFFE65100);
        break;
      case 'HALF_DAY':
        badgeBg = const Color(0xFFFFE0B2);
        badgeText = const Color(0xFFE65100);
        break;
      case 'LEAVE':
      case 'PTO':
      case 'SICK':
        badgeBg = const Color(0xFFF2F3FF);
        badgeText = const Color(0xFF714B67);
        break;
      case 'ABSENT':
        badgeBg = const Color(0xFFFFDAD6);
        badgeText = const Color(0xFFBA1A1A);
        break;
      default:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF475569);
        break;
    }

    final checkInStr = item.checkIn != null ? DateFormat('hh:mm a').format(item.checkIn!) : '--:--';
    final checkOutStr = item.checkOut != null ? DateFormat('hh:mm a').format(item.checkOut!) : '--:--';
    final dateDisplay = item.checkIn != null
        ? DateFormat('EEE, MMM dd').format(item.checkIn!)
        : (item.dateStr.isNotEmpty ? item.dateStr : 'Date Log');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(Icons.schedule, color: badgeText, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateDisplay,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$checkInStr → $checkOutStr',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF4E444A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.isManualEdit || (item.auditNotes != null && item.auditNotes!.isNotEmpty))
                      Text(
                        item.auditNotes != null && item.auditNotes!.isNotEmpty ? 'Audit: ${item.auditNotes}' : 'Manual Edit',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF00696E), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.workedHours.toStringAsFixed(1)} Hrs${item.overtimeHours > 0 ? ' (+${item.overtimeHours.toStringAsFixed(1)}h OT)' : ''}',
              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayrollTab() {
    if (_employeePayslips.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 28, color: Color(0xFF714B67)),
            ),
            const SizedBox(height: 14),
            Text(
              'No Payslips Available',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
            ),
            const SizedBox(height: 6),
            Text(
              'There are no computed or confirmed payslips associated with this employee yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A)),
            ),
          ],
        ),
      );
    }

    final activeSlip = _getActivePayslip();
    final basicLine = activeSlip.lines.firstWhere(
      (l) => l.category == 'BASIC',
      orElse: () => PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: activeSlip.grossAmount * 0.60),
    );
    final allowanceTotal = activeSlip.lines
        .where((l) => l.category == 'ALLOWANCE')
        .fold(0.0, (sum, l) => sum + l.amount);
    final deductionTotal = activeSlip.lines
        .where((l) => l.category == 'DEDUCTION')
        .fold(0.0, (sum, l) => sum + l.amount.abs());

    final availableMonths = _employeePayslips.map((p) => '${p.periodStart} → ${p.periodEnd}').toSet().toList();

    return Column(
      children: [
        // Pay Period Month Selector Card
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
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF714B67)),
                      const SizedBox(width: 8),
                      Text(
                        'Select Salary Month',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Text(
                      'STATUS: ${activeSlip.status}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD6DAFE)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableMonths.contains(_selectedPayMonth) ? _selectedPayMonth : availableMonths.first,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF714B67)),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                    items: availableMonths.map((String m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF714B67)),
                            const SizedBox(width: 8),
                            Text(
                              m,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedPayMonth = val;
                          _selectedAttendanceMonth = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Salary Breakdown Card for Selected Month
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
                  Expanded(
                    child: Text(
                      'Payroll Breakdown',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFCCF7FA), borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      activeSlip.refCode,
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF006E73)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildOrgRow(
                icon: Icons.currency_rupee,
                iconColor: const Color(0xFF006443),
                title: 'Basic Salary',
                value: '₹ ${basicLine.amount.toStringAsFixed(2)} / Mo',
              ),
              const Divider(height: 20),
              _buildOrgRow(
                icon: Icons.add_circle_outline,
                iconColor: const Color(0xFF00696E),
                title: 'Allowances',
                value: '₹ ${allowanceTotal.toStringAsFixed(2)} / Mo',
              ),
              const Divider(height: 20),
              _buildOrgRow(
                icon: Icons.remove_circle_outline,
                iconColor: const Color(0xFFBA1A1A),
                title: 'Deductions',
                value: '- ₹ ${deductionTotal.toStringAsFixed(2)} / Mo',
              ),
              const Divider(height: 20),
              _buildOrgRow(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF714B67),
                title: 'Net Dispatched',
                value: '₹ ${activeSlip.netAmount.toStringAsFixed(2)}',
                trailing: Text(
                  'Gross: ₹ ${activeSlip.grossAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF714B67)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF714B67),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => PayslipPdfDialog(payslip: activeSlip),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(
                    'View & Download Payslip PDF',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    final String activeMonthStr = (_selectedTabIndex == 2) ? _selectedAttendanceMonth : _selectedPayMonth;
    final String selStart = activeMonthStr.contains('→') ? activeMonthStr.split('→').first.trim() : activeMonthStr;

    DateTime? periodDate = DateTime.tryParse(selStart);
    if (periodDate == null && selStart.length >= 7) {
      periodDate = DateTime.tryParse('${selStart.substring(0, 7)}-01');
    }
    periodDate ??= DateTime.now();

    final monthStr = DateFormat('MMM').format(periodDate);
    final yearMonthStr = DateFormat('yyyy-MM').format(periodDate);

    final activeSlip = _getActivePayslip();

    final userAttendances = MockDataService.attendances.where((a) {
      final isEmp = a.employeeId == emp.id ||
          (a.employeeName != null &&
              a.employeeName!.isNotEmpty &&
              emp.name.toLowerCase().contains(a.employeeName!.toLowerCase().split(' ').first));
      if (!isEmp) return false;
      if (a.checkIn != null) {
        return DateFormat('yyyy-MM').format(a.checkIn!) == yearMonthStr;
      }
      if (a.dateStr.length >= 7) {
        return a.dateStr.startsWith(yearMonthStr);
      }
      return false;
    }).toList();

    final double totalWorked = userAttendances.isNotEmpty
        ? userAttendances.fold(0.0, (sum, a) => sum + a.workedHours)
        : (activeSlip.periodStart.startsWith(yearMonthStr) && activeSlip.workedHours > 0
            ? activeSlip.workedHours
            : 0.0);

    final double targetHours = activeSlip.scheduledHours > 0 ? activeSlip.scheduledHours : 168.0;
    final double progress = (targetHours > 0) ? (totalWorked / targetHours).clamp(0.0, 1.0) : 0.0;
    final int percentage = (progress * 100).round();

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
                    'Pay Cycle Accrual ($monthStr)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                  Text(
                    '${totalWorked.toStringAsFixed(1)} / ${targetHours.toStringAsFixed(1)} Hrs',
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
          // Circular progress indicator
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: const Color(0xFFDAE2FD),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00696E)),
                ),
                Center(
                  child: Text(
                    '$percentage%',
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
    if (!_canEdit) return const SizedBox.shrink();

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
