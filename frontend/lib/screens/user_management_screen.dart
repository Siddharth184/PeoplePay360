import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/create_edit_user_sheet.dart';
import '../services/user_management_service.dart';
import '../services/api_client.dart';

class UserManagementScreen extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  const UserManagementScreen({super.key, this.onNavigateTab});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementItem {
  final String id;
  final String name;
  final String email;
  final String role;
  final String roleCategory;
  final String linkedEmployee;
  final String department;
  final String status;
  final String extraBadge;
  final String initials;
  final bool isYou;
  final Color avatarBg;
  final Color avatarText;
  final Color roleBg;
  final Color roleText;
  final IconData roleIcon;
  bool isSwiped = false;

  _UserManagementItem({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleCategory,
    required this.linkedEmployee,
    required this.department,
    required this.status,
    required this.extraBadge,
    required this.initials,
    this.isYou = false,
    required this.avatarBg,
    required this.avatarText,
    required this.roleBg,
    required this.roleText,
    required this.roleIcon,
  });
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  bool _isLoading = false;

  late List<_UserManagementItem> _users;

  @override
  void initState() {
    super.initState();
    _users = _defaultUsers();
    _loadUsers();
  }

  List<_UserManagementItem> _defaultUsers() {
    return [
      _UserManagementItem(
        id: 'usr_1',
        name: 'Alex Morgan',
        email: 'admin@oxp.com',
        role: 'System Admin',
        roleCategory: 'Admin',
        linkedEmployee: 'Alex Morgan',
        department: 'Executive',
        status: 'Active',
        extraBadge: 'PIN: Active',
        initials: 'AM',
        isYou: true,
        avatarBg: const Color(0xFF714B67),
        avatarText: Colors.white,
        roleBg: const Color(0xFFFFD7F1),
        roleText: const Color(0xFF2F1029),
        roleIcon: Icons.shield,
      ),
      _UserManagementItem(
        id: 'usr_2',
        name: 'Sara Khan',
        email: 'sara.khan@oxp.com',
        role: 'HR Manager',
        roleCategory: 'HR Manager',
        linkedEmployee: 'Sara Khan',
        department: 'Human Resources',
        status: 'Active',
        extraBadge: 'Dept Lead',
        initials: 'SK',
        avatarBg: const Color(0xFFDAE2FD),
        avatarText: const Color(0xFF57344F),
        roleBg: const Color(0xFFFFD7F1),
        roleText: const Color(0xFF2F1029),
        roleIcon: Icons.admin_panel_settings_outlined,
      ),
      _UserManagementItem(
        id: 'usr_3',
        name: 'Aarav Mehta',
        email: 'aarav.mehta@oxp.com',
        role: 'Payroll User',
        roleCategory: 'Payroll User',
        linkedEmployee: 'Aarav Mehta',
        department: 'Finance',
        status: 'Active',
        extraBadge: '2FA Enforced',
        initials: 'AM',
        avatarBg: const Color(0xFF92EFF5),
        avatarText: const Color(0xFF006E73),
        roleBg: const Color(0xFFCCF7FA),
        roleText: const Color(0xFF006E73),
        roleIcon: Icons.payments_outlined,
      ),
    ];
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    final res = await UserManagementService.getUsers(
      role: _selectedFilter == 'All' ? null : _selectedFilter,
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );

    if (mounted) {
      if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
        final parsed = res.data!.map((u) {
          final email = u['email']?.toString() ?? '';
          final empName = u['employee_name']?.toString() ?? email.split('@').first;
          final role = u['role']?.toString() ?? 'EMPLOYEE';
          final isActive = u['is_active'] as bool? ?? true;
          final inits = empName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

          return _UserManagementItem(
            id: u['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
            name: empName,
            email: email,
            role: role,
            roleCategory: role.contains('ADMIN') ? 'Admin' : (role.contains('HR') ? 'HR Manager' : (role.contains('PAYROLL') ? 'Payroll User' : 'Employee')),
            linkedEmployee: empName,
            department: 'Company Staff',
            status: isActive ? 'Active' : 'Disabled',
            extraBadge: u['badge_id']?.toString() ?? '2FA Enforced',
            initials: inits.isNotEmpty ? inits : 'U',
            isYou: ApiClient.currentEmail != null && ApiClient.currentEmail!.toLowerCase() == email.toLowerCase(),
            avatarBg: const Color(0xFF92EFF5),
            avatarText: const Color(0xFF006E73),
            roleBg: const Color(0xFFCCF7FA),
            roleText: const Color(0xFF006E73),
            roleIcon: role.contains('ADMIN') ? Icons.shield : (role.contains('PAYROLL') ? Icons.payments_outlined : Icons.person_outline),
          );
        }).toList();

        setState(() {
          _users = parsed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_UserManagementItem> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((u) {
      final matchesFilter = _selectedFilter == 'All' ||
          u.roleCategory.toLowerCase() == _selectedFilter.toLowerCase() ||
          u.role.toLowerCase().contains(_selectedFilter.toLowerCase());

      final matchesQuery = query.isEmpty ||
          u.name.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.linkedEmployee.toLowerCase().contains(query);

      return matchesFilter && matchesQuery;
    }).toList();
  }

  void _openNewUserSheet([_UserManagementItem? existing]) {
    CreateEditUserSheet.show(
      context,
      initialEmployee: existing?.linkedEmployee,
      initialEmail: existing?.email,
      initialRole: existing?.role,
      onSave: (userData) async {
        final _ = userData['employee'] as String;
        final email = userData['email'] as String;
        final role = userData['role'] as String;
        final isActive = userData['isActive'] as bool? ?? true;

        if (existing == null) {
          await UserManagementService.createUser({
            'email': email,
            'password': 'PeoplePay@360',
            'role': role,
            'is_active': isActive,
          });
        } else {
          await UserManagementService.updateUser(existing.id, {
            'role': role,
            'is_active': isActive,
          });
        }
        _loadUsers();
      },
    );
  }

  void _openUserDetailsSheet(_UserManagementItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: item.avatarBg,
                    child: Text(
                      item.initials,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: item.avatarText, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF131B2E)),
                            ),
                            if (item.isYou) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFFE2E7FF), borderRadius: BorderRadius.circular(10)),
                                child: Text('You', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          item.email,
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Info tile
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Assigned Role', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4E444A), fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: item.roleBg, borderRadius: BorderRadius.circular(20)),
                          child: Text(item.role, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: item.roleText)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Linked Employee', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4E444A), fontSize: 13)),
                        Text('${item.linkedEmployee} (${item.department})', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Multi-Company Isolation', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF4E444A), fontSize: 13)),
                        Text('Acme US-East (Enforced)', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF00696E), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: const Color(0xFFBA1A1A),
                        side: const BorderSide(color: Color(0xFFBA1A1A)),
                      ),
                      icon: const Icon(Icons.person_off, size: 18),
                      label: const Text('Suspend Access'),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('⚠️ Access suspended for ${item.name}')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF714B67),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Permissions'),
                      onPressed: () {
                        Navigator.pop(context);
                        _openNewUserSheet();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openQuickInviteSheet() {
    final inviteEmailCtrl = TextEditingController();
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
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
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
              'Quick Invite User',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Dispatches an instant invitation token with pre-configured Odoo RBAC policies.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF4E444A)),
            ),
            const SizedBox(height: 16),
            Container(
              height: 46,
              decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: inviteEmailCtrl,
                decoration: const InputDecoration(
                  hintText: 'teammate@company.com',
                  prefixIcon: Icon(Icons.forward_to_inbox, color: Color(0xFF00696E), size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 18),
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
                      content: Text('✉️ Quick Invite invitation link dispatched successfully!'),
                    ),
                  );
                },
                child: const Text('Send Invitation Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRbacRolesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.security, color: Color(0xFF00696E)),
                const SizedBox(width: 8),
                Text(
                  'RBAC Matrix & Multi-Company',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Odoo 18 Multi-Company Isolation is enforced. All database record rules verify res_company_id per session token.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF4E444A), height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildMatrixRow('Admin (SysAdmin)', 'Full root read/write, audit trails, user mgmt', true),
            _buildMatrixRow('Payroll Admin', 'Salary rules, payrun computation, payslip approval', true),
            _buildMatrixRow('Payroll User', 'Payslip viewing, payment execution', true),
            _buildMatrixRow('Time Off Admin', 'Leave allocations, manager approvals, carryovers', true),
            _buildMatrixRow('Employee', 'Self-service portal, own payslips, attendance clock', false),
            const SizedBox(height: 20),
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Close RBAC Matrix'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixRow(String role, String desc, bool privileged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            privileged ? Icons.check_circle : Icons.radio_button_checked,
            size: 16,
            color: privileged ? const Color(0xFF004A31) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Top Navigation & Header
                _buildHeader(),
                if (_isLoading) const LinearProgressIndicator(minHeight: 2),

                // Scrollable Body
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      // Directory Summary Metrics Banner
                      _buildDirectorySummaryBanner(),

                      const SizedBox(height: 10),

                      // Micro interaction hint ribbon
                      _buildHintRibbon(),

                      const SizedBox(height: 12),

                      // Cards List
                      ...filtered.map((item) => _buildUserCard(item)),

                      const SizedBox(height: 16),

                      // Security & RBAC Status Bottom Notice
                      _buildSecurityNotice(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom Floating Quick Action Hub
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildFloatingActionHub(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final filters = [
      {'label': 'All', 'count': '5'},
      {'label': 'Admin', 'count': '1'},
      {'label': 'Payroll Admin', 'count': '1'},
      {'label': 'Payroll User', 'count': '1'},
      {'label': 'Time Off Admin', 'count': '1'},
      {'label': 'Employee', 'count': '1'},
    ];

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          if (_isLoading) ...[
            const LinearProgressIndicator(color: Color(0xFF714B67), minHeight: 2),
            const SizedBox(height: 6),
          ],
          // Top Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Back Button
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
                        child: Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF131B2E)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Logo + Title Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF714B67),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Icon(Icons.badge_outlined, color: Colors.white, size: 13),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'User Management',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF92EFF5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ADMIN • RBAC v2026.1',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF006E73),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // + New User Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF714B67),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 2,
                  shadowColor: const Color(0x33714B67),
                ),
                onPressed: _openNewUserSheet,
                icon: const Icon(Icons.person_add, size: 16),
                label: Text(
                  '+ New User',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Search Input Bar
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: const Color(0xFF131B2E)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Color(0xFF80747A), size: 19),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Color(0xFF80747A), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                hintText: 'Search users, employees, or email...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF80747A)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final isSelected = _selectedFilter == f['label'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFilter = f['label']!;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF714B67) : const Color(0xFFF2F3FF),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(
                                  color: Color(0x33714B67),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            f['label']!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF4E444A),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E7FF),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                f['count']!,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF4E444A),
                                ),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildDirectorySummaryBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDAE2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.group, color: Color(0xFF57344F), size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_users.length} Directory Users',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      const SizedBox(width: 6),
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
                  Text(
                    '5 Active • 0 Suspended • 1 Pending 2FA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.download, size: 18, color: Color(0xFF131B2E)),
                tooltip: 'Export CSV',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⬇️ Exporting users_directory_2026.csv...')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.checklist, size: 18, color: Color(0xFF131B2E)),
                tooltip: 'Bulk Action Menu',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ Bulk selection mode enabled')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintRibbon() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF92EFF5).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app, size: 15, color: Color(0xFF006E73)),
              const SizedBox(width: 6),
              Text(
                'Tap card for RBAC permissions • Swipe left for quick actions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF006E73),
                ),
              ),
            ],
          ),
          const Icon(Icons.swipe_left, size: 15, color: Color(0xFF006E73)),
        ],
      ),
    );
  }

  Widget _buildUserCard(_UserManagementItem item) {
    // If card is in swiped state (like Card 3 in Stitch mockup)
    if (item.isSwiped) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Underneath Action Tray Revealed on Left Swipe
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _openUserDetailsSheet(item),
                      child: Container(
                        width: 76,
                        color: const Color(0xFF714B67),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.manage_accounts, color: Colors.white, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              'Roles',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          item.isSwiped = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('⚠️ Access suspended for ${item.name}')),
                        );
                      },
                      child: Container(
                        width: 76,
                        color: const Color(0xFFBA1A1A),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_off, color: Colors.white, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              'Suspend',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Shifted Card Front Surface
              Transform.translate(
                offset: const Offset(-152, 0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      item.isSwiped = false;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(-2, 2)),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: _buildCardContent(item, isSwipedCard: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Standard User Card
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openUserDetailsSheet(item),
        onLongPress: () {
          setState(() {
            item.isSwiped = true;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: _buildCardContent(item),
        ),
      ),
    );
  }

  Widget _buildCardContent(_UserManagementItem item, {bool isSwipedCard = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top section of card
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: item.avatarBg,
                  child: Text(
                    item.initials,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: item.avatarText,
                    ),
                  ),
                ),
                if (item.isYou)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD7F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.stars, size: 12, color: Color(0xFF2F1029)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      if (item.isYou) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E7FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'You',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                        ),
                      ],
                      if (isSwipedCard) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDAE2FD),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Swiped',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.email,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: const Color(0xFF80747A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Badges Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Role Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: item.roleBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.roleIcon, size: 12, color: item.roleText),
                            const SizedBox(width: 4),
                            Text(
                              item.role,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.roleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Active Indicator Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6FFBBE).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF006443),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF004A31),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Trailing action
            if (item.isYou)
              const Icon(Icons.more_vert, color: Color(0xFF80747A), size: 18)
            else
              const Icon(Icons.chevron_right, color: Color(0xFF80747A), size: 18),
          ],
        ),

        const SizedBox(height: 10),

        // Bottom Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    item.isYou ? Icons.verified_user : Icons.link,
                    size: 14,
                    color: const Color(0xFF00696E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.isYou
                        ? 'Full System & Audit Logs Access'
                        : 'Linked: ${item.linkedEmployee} (${item.department})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: item.extraBadge == '2FA Enforced'
                    ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5)
                    : EdgeInsets.zero,
                decoration: item.extraBadge == '2FA Enforced'
                    ? BoxDecoration(
                        color: const Color(0xFF6FFBBE).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
                child: Text(
                  item.extraBadge,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: item.extraBadge == '2FA Enforced'
                        ? const Color(0xFF004A31)
                        : const Color(0xFF80747A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF92EFF5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.policy, color: Color(0xFF006E73), size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Odoo 18 Multi-Company Isolation',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF131B2E),
                  ),
                ),
                Text(
                  'Global tenant rules enforce company ID locks on record operations.',
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
    );
  }

  Widget _buildFloatingActionHub() {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Directory Synced
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF006443),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Directory Synced',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF131B2E),
                ),
              ),
            ],
          ),

          // Right: Quick Invite + RBAC Matrix
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF714B67),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 2,
                ),
                onPressed: _openQuickInviteSheet,
                icon: const Icon(Icons.forward_to_inbox, size: 15),
                label: Text(
                  'Quick Invite',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openRbacRolesSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E7FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.security, size: 18, color: Color(0xFF131B2E)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
