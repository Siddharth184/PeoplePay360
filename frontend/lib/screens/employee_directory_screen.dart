import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../services/mock_data_service.dart';
import '../services/employee_service.dart';
import '../models/models.dart';
import 'employee_profile_screen.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const EmployeeDirectoryScreen({super.key, this.onNavigateTab});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  bool _isKanbanView = true;
  String _searchQuery = '';
  String _selectedDept = 'all';
  List<EmployeeModel> _staffList = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _deptFilterConfigs = [
    {'id': 'all', 'label': 'All Departments'},
    {'id': 'finance', 'label': 'Finance'},
    {'id': 'engineering', 'label': 'Engineering'},
    {'id': 'hr', 'label': 'HR'},
    {'id': 'sales', 'label': 'Sales'},
  ];

  @override
  void initState() {
    super.initState();
    _staffList = MockDataService.allEmployees;
    _fetchEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    final res = await EmployeeService.getEmployees(
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          _staffList = res.data!;
        } else {
          _staffList = List<EmployeeModel>.from(MockDataService.allEmployees);
        }
      });
    }
  }

  void _triggerToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: const Color(0xFF283044),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        duration: const Duration(seconds: 2),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF6FFBBE), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateEmployeeSheet() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+91 98765 ');
    final badgeIdCtrl = TextEditingController(text: 'EMP-${4000 + MockDataService.allEmployees.length + 1}');
    final joiningDateCtrl = TextEditingController(text: '2026-09-01');
    final wageCtrl = TextEditingController(text: '85000');
    final bankAccountCtrl = TextEditingController(text: '5010-9941-${1000 + MockDataService.allEmployees.length + 1}');

    String jobTitle = 'Software Engineer';
    String dept = 'Engineering';
    String location = 'Bengaluru HQ';
    String manager = 'Sara Khan';
    String empType = 'Full-time';
    String bankName = 'HDFC Bank';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF57344F).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF57344F), size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Onboard New Employee',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // SECTION 1: PERSONAL & CONTACT
                    _buildFormSectionHeader('1. Personal & Contact Information', Icons.badge_outlined),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Full Name *', Icons.person_outline, hint: 'e.g. Aarav Mehta'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Work Email *', Icons.email_outlined, hint: 'aarav@oxp.com'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Work Phone *', Icons.phone_outlined, hint: '+91 98765 43210'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: badgeIdCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Employee Badge ID *', Icons.qr_code_outlined, hint: 'EMP-4095'),
                    ),
                    const SizedBox(height: 20),

                    // SECTION 2: ROLE & ASSIGNMENT
                    _buildFormSectionHeader('2. Role & Organizational Assignment', Icons.business_outlined),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: jobTitle,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Job Position / Role *', Icons.work_outline),
                      items: const [
                        DropdownMenuItem(value: 'Software Engineer', child: Text('Software Engineer', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Payroll Specialist', child: Text('Payroll Specialist', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'HR Manager', child: Text('HR Manager', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'HR Payroll User', child: Text('HR Payroll User', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Product Manager', child: Text('Product Manager', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Financial Analyst', child: Text('Financial Analyst', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Operations Lead', child: Text('Operations Lead', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Sales Manager', child: Text('Sales Manager', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Data Analyst', child: Text('Data Analyst', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'QA Engineer', child: Text('QA Engineer', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'System Administrator', child: Text('System Administrator', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => jobTitle = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: dept,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Department *', Icons.apartment_outlined),
                      items: const [
                        DropdownMenuItem(value: 'Engineering', child: Text('Engineering', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Finance', child: Text('Finance', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Human Resources', child: Text('Human Resources', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Sales', child: Text('Sales', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Marketing', child: Text('Marketing', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Executive Management', child: Text('Executive Management', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Customer Support', child: Text('Customer Support', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => dept = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: location,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Office Location *', Icons.location_on_outlined),
                      items: const [
                        DropdownMenuItem(value: 'Bengaluru HQ', child: Text('Bengaluru HQ', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Mumbai Hub', child: Text('Mumbai Hub', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Delhi NCR', child: Text('Delhi NCR', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Hyderabad Tech', child: Text('Hyderabad Tech', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Remote', child: Text('Remote', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => location = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: manager,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Reporting Manager *', Icons.supervisor_account_outlined),
                      items: const [
                        DropdownMenuItem(value: 'Sara Khan', child: Text('Sara Khan (HR Director)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Vikram Nair', child: Text('Vikram Nair (Finance Lead)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Aarav Mehta', child: Text('Aarav Mehta (Payroll Lead)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Admin User', child: Text('Admin User', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Board of Directors', child: Text('Board of Directors', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => manager = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: empType,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Employment Type *', Icons.category_outlined),
                      items: const [
                        DropdownMenuItem(value: 'Full-time', child: Text('Full-time', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Part-time', child: Text('Part-time', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Contractor', child: Text('Contractor', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Intern', child: Text('Intern', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Probation', child: Text('Probation', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => empType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: joiningDateCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Date of Joining (YYYY-MM-DD) *', Icons.calendar_month_outlined),
                    ),
                    const SizedBox(height: 20),

                    // SECTION 3: BANKING & COMPENSATION
                    _buildFormSectionHeader('3. Banking & Payroll Setup', Icons.account_balance_outlined),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: wageCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Monthly Wage / Base Salary (₹) *', Icons.payments_outlined, hint: '85000'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: bankName,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Bank Name *', Icons.account_balance_wallet_outlined),
                      items: const [
                        DropdownMenuItem(value: 'HDFC Bank', child: Text('HDFC Bank', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'ICICI Bank', child: Text('ICICI Bank', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Axis Bank', child: Text('Axis Bank', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'State Bank of India', child: Text('State Bank of India (SBI)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'Kotak Mahindra Bank', child: Text('Kotak Mahindra Bank', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'IndusInd Bank', child: Text('IndusInd Bank', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => bankName = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bankAccountCtrl,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF131B2E)),
                      decoration: _buildInputDecoration('Bank Account No. *', Icons.numbers_outlined, hint: '5010-9941-8812'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00696E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (isSubmitting) return;

                          final name = nameCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final badgeId = badgeIdCtrl.text.trim();
                          final joiningDate = joiningDateCtrl.text.trim();
                          final wageStr = wageCtrl.text.trim();
                          final bankAcc = bankAccountCtrl.text.trim();

                          if (name.isEmpty || email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚠️ Please enter Full Name and Work Email')),
                            );
                            return;
                          }

                          setSheetState(() => isSubmitting = true);

                          Navigator.of(context).pop();
                          _triggerToast('⏳ Onboarding employee...');

                          await EmployeeService.createEmployee({
                            'name': name,
                            'work_email': email,
                            'phone': phone,
                            'badge_id': badgeId,
                            'job_position_name': jobTitle,
                            'department_name': dept,
                            'work_location': location,
                            'manager_name': manager,
                            'employee_type': empType,
                            'date_of_joining': joiningDate,
                            'wage_monthly': double.tryParse(wageStr) ?? 85000.0,
                            'bank_name': bankName,
                            'bank_account_number': bankAcc,
                            'company_name': 'OXP Pvt Ltd',
                          });

                          if (mounted) {
                            await _fetchEmployees();
                            _triggerToast('✅ Employee onboarded & active contract created');
                          }
                        },
                        icon: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: Text(
                          isSubmitting ? 'Saving...' : 'Save & Complete Onboarding',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
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

  Widget _buildFormSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF57344F)),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF57344F),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF57344F), fontSize: 13, fontWeight: FontWeight.w600),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF714B67), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF714B67), width: 1.5)),
    );
  }

  bool _matchesDepartment(EmployeeModel emp, String deptId) {
    if (deptId == 'all') return true;
    final d = emp.department.toLowerCase();
    if (deptId == 'finance') return d.contains('fin') || d.contains('pay');
    if (deptId == 'engineering') return d.contains('eng') || d.contains('dev') || d.contains('tech');
    if (deptId == 'hr') return d.contains('hr') || d.contains('human') || d.contains('people');
    if (deptId == 'sales') return d.contains('sal') || d.contains('mark');
    return d.contains(deptId);
  }

  int _getDeptCount(String deptId) {
    if (deptId == 'all') return _staffList.length;
    return _staffList.where((e) => _matchesDepartment(e, deptId)).length;
  }

  Color _getDeptColor(String dept) {
    final d = dept.toLowerCase();
    if (d.contains('fin')) return const Color(0xFF00696E);
    if (d.contains('eng') || d.contains('dev')) return const Color(0xFF714B67);
    if (d.contains('hr') || d.contains('people')) return const Color(0xFF57344F);
    if (d.contains('sal') || d.contains('mark')) return const Color(0xFFD97706);
    return const Color(0xFF00696E);
  }

  Color _getDeptBgColor(String dept) {
    final d = dept.toLowerCase();
    if (d.contains('fin')) return const Color(0xFF92EFF5).withValues(alpha: 0.35);
    if (d.contains('eng') || d.contains('dev')) return const Color(0xFFDAE2FD);
    if (d.contains('hr') || d.contains('people')) return const Color(0xFFFFD7F1).withValues(alpha: 0.6);
    if (d.contains('sal') || d.contains('mark')) return const Color(0xFFFEF3C7);
    return const Color(0xFFEAEDFF);
  }

  List<Color> _getAvatarGradients(int index, String name) {
    final gradients = [
      [const Color(0xFF714B67), const Color(0xFF00696E)],
      [const Color(0xFF00696E), const Color(0xFF00A09D)],
      [const Color(0xFF283044), const Color(0xFF714B67)],
      [const Color(0xFFD97706), const Color(0xFFF59E0B)],
      [const Color(0xFF57344F), const Color(0xFF8B5CF6)],
      [const Color(0xFF047857), const Color(0xFF10B981)],
    ];
    final hash = (name.hashCode.abs() + index) % gradients.length;
    return gradients[hash];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'EM';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _getBadgeId(EmployeeModel emp, int index) {
    if (emp.badgeId != null && emp.badgeId!.isNotEmpty) {
      return emp.badgeId!;
    }
    final num = (index * 73 + 102) % 900 + 100;
    return '#OX-$num';
  }

  bool _isOnLeave(EmployeeModel emp, int index) {
    if (emp.status != null) {
      return emp.status!.toLowerCase().contains('leave') || emp.status!.toLowerCase().contains('pto');
    }
    return (index == 3 || index == 7);
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _staffList.where((emp) {
      final matchesQuery = emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.department.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDept = _matchesDepartment(emp, _selectedDept);
      return matchesQuery && matchesDept;
    }).toList();

    // Metric counts
    final totalCount = _staffList.length;
    final leaveCount = _staffList.where((e) => _isOnLeave(e, _staffList.indexOf(e))).length;
    final onDutyCount = totalCount > leaveCount ? totalCount - leaveCount : totalCount;
    final presentPct = totalCount > 0 ? ((onDutyCount / totalCount) * 100).toStringAsFixed(1) : '92.8';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Stack(
          children: [
            // Top Ambient Glow Aura
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD7F1).withValues(alpha: 0.4),
                ),
              ),
            ),
            Positioned(
              top: 30,
              left: -30,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF95F1F8).withValues(alpha: 0.35),
                ),
              ),
            ),

            // Main Content Area
            RefreshIndicator(
              onRefresh: _fetchEmployees,
              color: const Color(0xFF714B67),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // App Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Title & Count Pill
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.onNavigateTab == null && Navigator.canPop(context)) ...[
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back, color: Color(0xFF131B2E), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          final route = ModalRoute.of(context);
                                          if (route != null && !route.isFirst) {
                                            Navigator.pop(context);
                                          } else if (widget.onNavigateTab != null) {
                                            widget.onNavigateTab!(-1);
                                          } else if (Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Flexible(
                                      child: Text(
                                        'Employees',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF131B2E),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF714B67).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$totalCount',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF57344F),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 4),

                              // Segmented View Switcher Pill
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E7FF).withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (!_isKanbanView) {
                                          setState(() => _isKanbanView = true);
                                          _triggerToast('Switched to Kanban Cards');
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _isKanbanView ? const Color(0xFF714B67) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: _isKanbanView
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFF714B67).withValues(alpha: 0.25),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.grid_view_rounded,
                                              size: 13,
                                              color: _isKanbanView ? Colors.white : const Color(0xFF4E444A),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Kanban',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: _isKanbanView ? Colors.white : const Color(0xFF4E444A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (_isKanbanView) {
                                          setState(() => _isKanbanView = false);
                                          _triggerToast('Switched to Full List View');
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: !_isKanbanView ? const Color(0xFF714B67) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: !_isKanbanView
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFF714B67).withValues(alpha: 0.25),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.format_list_bulleted_rounded,
                                              size: 13,
                                              color: !_isKanbanView ? Colors.white : const Color(0xFF4E444A),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'List',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: !_isKanbanView ? Colors.white : const Color(0xFF4E444A),
                                              ),
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
                          Text(
                            'OXP Enterprise Workforce',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF4E444A),
                            ),
                          ),

                          // Quick Metrics Strip
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              // On Duty
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFEAEDFF)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
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
                                          Text(
                                            'On Duty',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: const Color(0xFF4E444A),
                                            ),
                                          ),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF006443),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$onDutyCount',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF131B2E),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '$presentPct% present',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF00696E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // On Leave
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFEAEDFF)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
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
                                          Text(
                                            'On Leave',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: const Color(0xFF4E444A),
                                            ),
                                          ),
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF59E0B),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$leaveCount',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF131B2E),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '2 PTO · 1 Med',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Pay Run
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFEAEDFF)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
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
                                          Text(
                                            'Pay Run',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: const Color(0xFF4E444A),
                                            ),
                                          ),
                                          const Icon(Icons.schedule, size: 14, color: Color(0xFF714B67)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'T-3d',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF714B67),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'Oct Cycle',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF714B67),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Search Bar
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFEAEDFF)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.search, color: Color(0xFF80747A), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF131B2E)),
                                    decoration: InputDecoration(
                                      hintText: 'Search by name, job, or team...',
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: const Color(0xFF80747A).withValues(alpha: 0.7),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(Icons.close, size: 18, color: Colors.grey),
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: () => _triggerToast('Voice search activated... Speak now'),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEAEDFF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.mic, size: 18, color: Color(0xFF4E444A)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Horizontal Department Filter Chips
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: _deptFilterConfigs.map((cfg) {
                                final isSelected = _selectedDept == cfg['id'];
                                final count = _getDeptCount(cfg['id']!);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedDept = cfg['id']!);
                                      _triggerToast('Filtered by ${cfg['label']}');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF714B67) : const Color(0xFFEAEDFF),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF714B67).withValues(alpha: 0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            cfg['label']!,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              color: isSelected ? Colors.white : const Color(0xFF131B2E),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '($count)',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white.withValues(alpha: 0.85)
                                                  : const Color(0xFF4E444A).withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Loading Indicator
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        color: Color(0xFF714B67),
                        backgroundColor: Color(0xFFEAEDFF),
                        minHeight: 2,
                      ),
                    ),

                  // Empty State
                  if (filteredStaff.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.person_search_outlined, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No employees found matching "$_searchQuery"',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Content: Kanban Grid or List View
                  if (filteredStaff.isNotEmpty && _isKanbanView) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final emp = filteredStaff[index];
                            final onLeave = _isOnLeave(emp, index);
                            final badgeId = _getBadgeId(emp, index);
                            final grad = _getAvatarGradients(index, emp.name);
                            final deptColor = _getDeptColor(emp.department);
                            final deptBg = _getDeptBgColor(emp.department);

                            return _buildKanbanCard(
                              emp: emp,
                              index: index,
                              onLeave: onLeave,
                              badgeId: badgeId,
                              gradientColors: grad,
                              deptColor: deptColor,
                              deptBg: deptBg,
                            );
                          },
                          childCount: filteredStaff.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    // Directory Quick View Preview Strip
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Directory Quick View',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF131B2E),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF00696E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _isKanbanView = false);
                                    _triggerToast('Switched to Full List View');
                                  },
                                  child: Text(
                                    'See all list ›',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF00696E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...filteredStaff.take(2).map((emp) {
                              final idx = filteredStaff.indexOf(emp);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildListTile(emp, idx),
                              );
                            }),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ] else if (filteredStaff.isNotEmpty && !_isKanbanView) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final emp = filteredStaff[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildListTile(emp, index),
                            );
                          },
                          childCount: filteredStaff.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ],
              ),
            ),

            // Floating Action Button (+ NEW) - HR+ Only
            if (ApiClient.hasHrAccess)
              Positioned(
                right: 16,
                bottom: 24,
                child: GestureDetector(
                  onTap: _openCreateEmployeeSheet,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00696E),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00696E).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '+ NEW',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
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
    );
  }

  Widget _buildKanbanCard({
    required EmployeeModel emp,
    required int index,
    required bool onLeave,
    required String badgeId,
    required List<Color> gradientColors,
    required Color deptColor,
    required Color deptBg,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAEDFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeProfileScreen(initialEmployee: emp),
              ),
            ).then((_) => _fetchEmployees());
          },
          child: Stack(
            children: [
              // Top-right subtle ambient corner decor
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: onLeave
                        ? const Color(0xFFFEF3C7).withValues(alpha: 0.6)
                        : const Color(0xFFFFD7F1).withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(36),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Avatar with Status Dot + Status Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: gradientColors,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradientColors[0].withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(emp.name),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                                  color: onLeave ? const Color(0xFFF59E0B) : const Color(0xFF006443),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: onLeave
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFF6FFBBE).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: onLeave ? const Color(0xFFD97706) : const Color(0xFF006443),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                onLeave ? 'On Leave' : 'Active',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: onLeave ? const Color(0xFF92400E) : const Color(0xFF006443),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    // Name
                    Text(
                      emp.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Job Title
                    Text(
                      emp.jobTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF4E444A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Department Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: deptBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        emp.department,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: deptColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const Spacer(),

                    // Bottom Strip: ID and Quick Action Buttons
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFF2F3FF), width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'ID: $badgeId',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                color: const Color(0xFF4E444A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (onLeave) {
                                    _triggerToast('${emp.name} is on PTO until Monday');
                                  } else {
                                    _triggerToast('Calling ${emp.name}...');
                                  }
                                },
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F3FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFEAEDFF)),
                                  ),
                                  child: Icon(
                                    Icons.phone_outlined,
                                    size: 13,
                                    color: onLeave ? const Color(0xFF80747A) : const Color(0xFF00696E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _triggerToast('Drafting email to ${emp.name}...'),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F3FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFEAEDFF)),
                                  ),
                                  child: const Icon(
                                    Icons.email_outlined,
                                    size: 13,
                                    color: Color(0xFF714B67),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(EmployeeModel emp, int index) {
    final onLeave = _isOnLeave(emp, index);
    final grad = _getAvatarGradients(index, emp.name);
    final deptColor = _getDeptColor(emp.department);
    final deptBg = _getDeptBgColor(emp.department);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEDFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeProfileScreen(initialEmployee: emp),
              ),
            ).then((_) => _fetchEmployees());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar with Status Dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: grad,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(emp.name),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: onLeave ? const Color(0xFFF59E0B) : const Color(0xFF006443),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              emp.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF131B2E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: deptBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              emp.department,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: deptColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              emp.jobTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF4E444A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ),
                          Flexible(
                            child: Text(
                              emp.email,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                color: const Color(0xFF4E444A).withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status Tag & Chevron
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: onLeave
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFF6FFBBE).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    onLeave ? 'On Leave' : 'Active',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: onLeave ? const Color(0xFF92400E) : const Color(0xFF006443),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Color(0xFF80747A), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
