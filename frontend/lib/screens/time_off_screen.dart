import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/time_off_service.dart';
import '../services/api_client.dart';
import '../services/mock_data_service.dart';

class TimeOffScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const TimeOffScreen({super.key, this.onNavigateTab});

  @override
  State<TimeOffScreen> createState() => _TimeOffScreenState();
}

class _TimeOffScreenState extends State<TimeOffScreen> with SingleTickerProviderStateMixin {
  String _selectedTab = 'To Approve';
  int _toReviewCount = 2;
  int _approvedCount = 14;
  late AnimationController _pulseController;

  // Custom Toast State
  bool _showToast = false;
  String _toastTitle = 'Request Approved';
  String _toastDesc = 'Syncing balance to Odoo payroll...';

  // Request Cards Data
  late List<Map<String, dynamic>> _requests;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _requests = _defaultRequests();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final res = await TimeOffService.getLeaveRequests();
    if (mounted && res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      final parsed = res.data!.map((req) {
        final isAppr = req.status == 'APPROVED';
        return {
          'id': req.id,
          'name': req.employeeName ?? 'Company Staff',
          'role': 'Staff Member',
          'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
          'type': req.typeName,
          'ref': req.id.length > 8 ? 'REQ-${req.id.substring(0, 8).toUpperCase()}' : 'REQ-2026',
          'dateRange': '${req.startDate} → ${req.endDate}',
          'days': req.daysCount.toInt(),
          'durationLabel': '${req.daysCount.toInt()} Working Days',
          'status': isAppr ? 'Approved' : 'To Approve',
          'isApproved': isAppr,
          'note': req.reason,
          'manager': 'Sara Khan',
          'managerInitials': 'SK',
          'time': 'Recent',
          'calendar': [
            {'day': 'DAY', 'num': '1', 'tag': 'Full Day', 'color': const Color(0xFF006443)},
          ],
          'leaveQuota': 'Annual Leave 2026',
          'remainingDays': 12,
        };
      }).toList();

      setState(() {
        _requests = parsed;
        _toReviewCount = parsed.where((r) => r['isApproved'] == false).length;
        _approvedCount = parsed.where((r) => r['isApproved'] == true).length;
      });
    }
  }

  List<Map<String, dynamic>> _defaultRequests() {
    return [
      {
        'id': 'aarav',
        'name': 'Aarav Mehta',
        'role': 'Payroll Specialist • Finance',
        'avatar':
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBVMA-35L2e3_o-eGu7X18aefNcekp6z7dH8Dx_OCYSdvOUnZOJ_aKzfPm09srJFE3dCRE3pYIf3VqCsF8FGHfOnhSqe6Q46zahYGcEwEzB_tNDXFiYC9q1lkXmTJDlYAg4f4CE2ekFTZwWx3qZUey6hHkqvjf99RXXD3Qs9OGvlmhKwnQQMtdXwIDIZRem3aQxCA5f5winn6ZUAHG6k6OldKshbD1hNTEId79b76QkwezEARk_thfk',
        'type': 'Paid Time Off',
        'ref': 'REQ-2026-8812',
        'dateRange': '12-Sep-2026 → 14-Sep-2026',
        'days': 3,
        'durationLabel': '3 Working Days',
        'status': 'To Approve',
        'isApproved': false,
        'note': 'Family vacation to Goa with advance handoff to John.',
        'manager': 'Sara Khan',
        'managerInitials': 'SK',
        'time': 'Today, 09:14 AM',
        'calendar': [
          {'day': 'THU', 'num': '12', 'tag': 'Full Day', 'color': const Color(0xFF006443)},
          {'day': 'FRI', 'num': '13', 'tag': 'Full Day', 'color': const Color(0xFF006443)},
          {'day': 'SAT', 'num': '14', 'tag': 'Shift Off', 'color': const Color(0xFF714B67)},
        ],
        'leaveQuota': 'Annual Leave 2026',
        'remainingDays': 12,
      },
      {
        'id': 'sara',
        'name': 'Sara Khan',
        'role': 'VP Finance & HR',
        'avatar':
            'https://lh3.googleusercontent.com/aida-public/AB6AXuACNQZit8WgWpBYJOr4xZbKMHZGf5Rt16Jh7Pb5IGSA8a6AQ2Y_oTZXK2rMptl1Z2ajxeTrUpeVCNWW5ilFR4bvQ4t7nXIivAGqVi7AVMbHH3_n8o1z2bhz8qFs7RvKrqNd49CPaY7fQQSxGzgIwoPSx5tXIMzEygize4QRnSMagqn-lRc3b4Fxp2w8fsdr_Jml2BYCeEhhLyKwBCU425qN0huBlsYfuEAtBIeUvGc4GnrGJTgmSFGG',
        'type': 'Sick Leave',
        'ref': 'REQ-2026-8809',
        'dateRange': '18-Sep-2026 (1 Working Day)',
        'days': 1,
        'durationLabel': '1 Working Day',
        'status': 'Approved',
        'isApproved': true,
        'note': 'Medical consultation & routine dental checkup.',
        'approvalNote': '1 Day • Medical Allowance (7d remaining)',
        'approver': 'By Alex Morgan • 2h ago',
      },
      {
        'id': 'john',
        'name': 'John Dsouza',
        'role': 'Payroll Specialist',
        'avatar':
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAyCQUAK9j8unakjbu-QEUkmBqw9HKfRdJY4ZGiP75yQ4qrz0Uv7uPGOr5cMxb02YyjHItkF8mxtCvh4iDEsRkkEyeQ8MjWugVRNp7UtjJVc5yoEGEWChzwBcVRDP2c9EzIUaT0bm2RUaZcOzGwOOISamZyVU__zoJh4O1M0x8rejwm_meSty5BMTH7e-VuZELOjD5O7dbtQjGy7ASyg0ZC3Hn_GLcQBiS9YMtuo9fJY8Rcp-zTXd7A',
        'type': 'Comp Off',
        'ref': 'REQ-2026-8794',
        'dateRange': '27-Sep-2026 (1 Working Day)',
        'days': 1,
        'durationLabel': '1 Working Day',
        'status': 'To Approve',
        'isApproved': false,
        'note': 'Compensatory off for weekend payroll deployment (Aug 30).',
        'extraInfo': 'Banked balance: 1 of 2 credits consumed.',
      },
    ];
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerToast(String title, String desc) {
    setState(() {
      _toastTitle = title;
      _toastDesc = desc;
      _showToast = true;
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  void _approveRequest(String id, String name, int days) async {
    setState(() {
      final req = _requests.firstWhere((r) => r['id'] == id, orElse: () => _requests.first);
      req['isApproved'] = true;
      req['status'] = 'Approved';
      _toReviewCount = (_toReviewCount > 0) ? _toReviewCount - 1 : 0;
      _approvedCount += 1;
    });
    _triggerToast('Request Approved ✓', '$name granted $days days. Ledger updated.');
    await TimeOffService.approveLeaveRequest(id);
  }

  void _rejectRequest(String id, String name) async {
    setState(() {
      _requests.removeWhere((r) => r['id'] == id);
      _toReviewCount = (_toReviewCount > 0) ? _toReviewCount - 1 : 0;
    });
    _triggerToast('Request Refused', '$name was notified with reason form.');
    await TimeOffService.refuseLeaveRequest(id, 'Request refused by Manager');
  }

  void _approveAllPending() {
    setState(() {
      for (var r in _requests) {
        if (!r['isApproved']) {
          r['isApproved'] = true;
          r['status'] = 'Approved';
        }
      }
      _approvedCount += _toReviewCount;
      _toReviewCount = 0;
    });
    _triggerToast('Bulk Approved ⚡', 'All pending requests signed off for Sep 25 cutoff.');
  }

  void _openNewLeaveSheet() {
    String selectedType = 'Paid Time Off (PTO)';
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                        child: const Icon(Icons.beach_access, color: Color(0xFF006E73), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Request Time Off',
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
              Text('Time Off Type *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Paid Time Off (PTO)', child: Text('Paid Time Off (PTO) — 15d Balance')),
                      DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave — 8d Balance')),
                      DropdownMenuItem(value: 'Comp Off', child: Text('Compensatory Off — 2d Available')),
                      DropdownMenuItem(value: 'Unpaid Leave', child: Text('Unpaid Leave (Loss of Pay)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Date *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('16-Sep-2026', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              const Icon(Icons.calendar_month, size: 16, color: Color(0xFF00696E)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End Date *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('18-Sep-2026', style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              const Icon(Icons.calendar_month, size: 16, color: Color(0xFF00696E)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Reason / Description *', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Family function & personal travel',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF2F3FF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        backgroundColor: const Color(0xFF00696E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _requests.insert(0, {
                            'id': 'new_${DateTime.now().millisecondsSinceEpoch}',
                            'name': 'Aarav Mehta',
                            'role': 'Payroll Specialist • Finance',
                            'avatar':
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuBVMA-35L2e3_o-eGu7X18aefNcekp6z7dH8Dx_OCYSdvOUnZOJ_aKzfPm09srJFE3dCRE3pYIf3VqCsF8FGHfOnhSqe6Q46zahYGcEwEzB_tNDXFiYC9q1lkXmTJDlYAg4f4CE2ekFTZwWx3qZUey6hHkqvjf99RXXD3Qs9OGvlmhKwnQQMtdXwIDIZRem3aQxCA5f5winn6ZUAHG6k6OldKshbD1hNTEId79b76QkwezEARk_thfk',
                            'type': selectedType,
                            'ref': 'REQ-2026-8820',
                            'dateRange': '16-Sep-2026 → 18-Sep-2026',
                            'days': 3,
                            'durationLabel': '3 Working Days',
                            'status': 'To Approve',
                            'isApproved': false,
                            'note': reasonCtrl.text.isEmpty ? 'Personal leave application' : reasonCtrl.text,
                            'manager': 'Sara Khan',
                            'managerInitials': 'SK',
                            'time': 'Just now',
                            'leaveQuota': 'Annual Leave 2026',
                            'remainingDays': 9,
                          });
                          _toReviewCount += 1;
                        });
                        _triggerToast('Application Submitted', 'Request sent to Sara Khan for managerial approval.');
                      },
                      child: const Text('Submit Request'),
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

  @override
  Widget build(BuildContext context) {
    final bool isHrView = ApiClient.hasTimeOffApprovalAccess;
    final bool isEmployeeView = ApiClient.isEmployee;
    final currentEmpName = ApiClient.currentEmployeeName ?? MockDataService.currentEmployee.name;

    // RBAC: Employee sees only own requests; HR+ sees all
    final roleFilteredRequests = isEmployeeView
        ? _requests.where((r) => (r['name'] as String?)?.toLowerCase() == currentEmpName.toLowerCase()).toList()
        : _requests;

    final pendingList = roleFilteredRequests.where((r) => !r['isApproved']).toList();
    final approvedList = roleFilteredRequests.where((r) => r['isApproved']).toList();

    List<Map<String, dynamic>> displayedRequests;
    if (_selectedTab == 'To Approve' || _selectedTab == 'My Pending') {
      displayedRequests = pendingList;
    } else if (_selectedTab == 'Approved' || _selectedTab == 'My Approved') {
      displayedRequests = approvedList;
    } else {
      displayedRequests = roleFilteredRequests;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header & KPI Section
                  _buildHeaderSection(),

                  // Sticky Filter Bar
                  _buildFilterBar(pendingList.length),

                  // Fast Bulk Action Banner (HR+ only)
                  if (isHrView && pendingList.isNotEmpty) _buildBulkBanner(pendingList.length),

                  // Request Cards Stream
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: displayedRequests.isEmpty && _selectedTab == 'To Approve'
                        ? _buildEmptyState()
                        : Column(
                            children: displayedRequests.map((r) => _buildRequestCard(r, showApprovalActions: isHrView)).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Delight Top Toast Alert
          if (_showToast)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildToastNotification(),
            ),

          // Floating Action Button
          Positioned(
            bottom: 24,
            right: 16,
            child: _buildFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildToastNotification() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFF006443),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _toastTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      Text(
                        _toastDesc,
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
          const SizedBox(width: 8),
          Text(
            'Just now',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF00696E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final bool isEmployeeView = ApiClient.isEmployee;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
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
                          color: Color(0xFFE2E7FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.arrow_back, color: Color(0xFF714B67), size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEmployeeView ? 'My Time Off' : 'Time Off Requests',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                          Text(
                            'PeoplePay360 • Q3 Cycle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF4E444A),
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
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔔 2 pending approval notifications in queue')),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.notifications_none, size: 20, color: Color(0xFF4E444A)),
                          Positioned(
                            top: 9,
                            right: 9,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFBA1A1A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF714B67),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDwBZfy06Jh2rsbPG8MxxCVAbD-LWSrDpFFI1lfV6pLpyBedkbcMUPv65VbkkBJaQ9au6e4ui1VfUjKJGz5RVEdO0D0aa8Z12vmh0X7e66GAmoKn-8t_nUfQ6F9ip3SkbuWSoi9GTQtm0XGuhdAARzUyHtNAjdtD9P3BSVwjHvYtOhzNI2V2og4FVkrY1uT7yCZHqEfSrC2BxSKKEny77IMgROW3xPjfhGMOSkiGUC6frK245vhJnH6',
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Live KPI Overview Ribbon
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // To Review
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) => Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF714B67).withValues(alpha: 0.4 + 0.6 * _pulseController.value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'To Review',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4E444A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_toReviewCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF714B67),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(width: 1, height: 26, color: const Color(0xFFDAE2FD)),

                // Approved
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approved',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4E444A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_approvedCount',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF006443),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(width: 1, height: 26, color: const Color(0xFFDAE2FD)),

                // Avg Turnaround
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avg Turnaround',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4E444A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '4.2h',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00696E),
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
    );
  }

  Widget _buildFilterBar(int pendingCount) {
    final bool isEmployeeView = ApiClient.isEmployee;
    final tabs = isEmployeeView
        ? [
            {'name': 'My Pending', 'badge': pendingCount > 0 ? '$pendingCount' : null},
            {'name': 'My Approved', 'badge': null},
            {'name': 'All Mine', 'badge': null},
          ]
        : [
            {'name': 'To Approve', 'badge': pendingCount > 0 ? '$pendingCount' : null},
            {'name': 'Approved', 'badge': null},
            {'name': 'All Requests', 'badge': null},
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: tabs.map((tab) {
          final isSel = _selectedTab == tab['name'];
          final badge = tab['badge'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = tab['name'] as String),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF714B67) : const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(20),
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
                  children: [
                    Text(
                      tab['name'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                        color: isSel ? Colors.white : const Color(0xFF4E444A),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA1A1A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBulkBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Color(0xFF00696E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count pending requests before cutoff (Sep 25).',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _approveAllPending,
            child: Text(
              'Approve All',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00696E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r, {bool showApprovalActions = true}) {
    final id = r['id'] as String;
    final name = r['name'] as String;
    final isApproved = r['isApproved'] as bool;
    final hasCalendar = r['calendar'] != null;

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name, Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF2F3FF),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        r['avatar'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(name.substring(0, 2).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                          Text(
                            r['role'] as String,
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
                  ],
                ),
              ),
              if (isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6FFBBE).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: Color(0xFF004A31)),
                      const SizedBox(width: 4),
                      Text(
                        'Approved',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF004A31),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDAE2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: Color(0xFF714B67), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'To Approve',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF714B67),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Leave Type & Reference
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF92EFF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r['type'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF006E73),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r['ref'] as String,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF80747A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Date Range & Duration
          Text(
            r['dateRange'] as String,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF131B2E),
            ),
          ),
          if (r['durationLabel'] != null && !isApproved) ...[
            const SizedBox(height: 2),
            Text(
              r['durationLabel'] as String,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00696E),
              ),
            ),
          ],

          // Calendar Strip (if available)
          if (hasCalendar) ...[
            const SizedBox(height: 10),
            Row(
              children: (r['calendar'] as List).map((c) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          c['day'] as String,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF80747A), fontWeight: FontWeight.bold),
                        ),
                        Text(
                          c['num'] as String,
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                        ),
                        Text(
                          c['tag'] as String,
                          style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w600, color: c['color'] as Color),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Balance Impact Widget (if available)
          if (r['leaveQuota'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.pie_chart_outline, size: 16, color: Color(0xFF00696E)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                r['leaveQuota'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${r['remainingDays']} days left',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4E444A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          Expanded(flex: 55, child: Container(color: const Color(0xFF006443))),
                          Expanded(flex: 15, child: Container(color: const Color(0xFF714B67))),
                          Expanded(flex: 30, child: Container(color: const Color(0xFFDAE2FD))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Consumes ${r['days']} days from quota. ${r['remainingDays']} days remaining after approval.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                  ),
                ],
              ),
            ),
          ],

          // Note / Reason
          if (r['note'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('🌴', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${r['note']}"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Approved footer metadata
          if (isApproved && r['approvalNote'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r['approvalNote'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r['approver'] ?? '',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF006443)),
                  ),
                ],
              ),
            ),
          ],

          // Manager Subtitle
          if (r['manager'] != null && !isApproved) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF714B67),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            r['managerInitials'] ?? 'M',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Direct Manager: ${r['manager']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF4E444A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r['time'] as String,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF80747A)),
                ),
              ],
            ),
          ],

          // Action Buttons: Refuse & Approve (HR+ only)
          if (!isApproved && showApprovalActions) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFDAD6),
                      foregroundColor: const Color(0xFFBA1A1A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => _rejectRequest(id, name),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(
                      'Refuse',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004A31),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => _approveRequest(id, name, r['days'] as int),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text(
                      'Approve',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF92EFF5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.celebration, color: Color(0xFF006E73), size: 30),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Inbox Zero! All Clear 🎉',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
          ),
          const SizedBox(height: 6),
          Text(
            'All pending time-off requests for the September payroll cycle have been processed.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDAE2FD),
              foregroundColor: const Color(0xFF714B67),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            onPressed: () => setState(() => _selectedTab = 'All Requests'),
            child: Text('Review All Requests', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00696E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 6,
      ),
      onPressed: _openNewLeaveSheet,
      icon: const Icon(Icons.add, size: 20),
      label: Text(
        'Request Leave',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
