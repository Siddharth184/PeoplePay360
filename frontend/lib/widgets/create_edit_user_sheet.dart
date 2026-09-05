import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateEditUserSheet extends StatefulWidget {
  final String? initialEmployee;
  final String? initialEmail;
  final String? initialRole;
  final Function(Map<String, dynamic> userData)? onSave;

  const CreateEditUserSheet({
    super.key,
    this.initialEmployee,
    this.initialEmail,
    this.initialRole,
    this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialEmployee,
    String? initialEmail,
    String? initialRole,
    Function(Map<String, dynamic> userData)? onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateEditUserSheet(
        initialEmployee: initialEmployee,
        initialEmail: initialEmail,
        initialRole: initialRole,
        onSave: onSave,
      ),
    );
  }

  @override
  State<CreateEditUserSheet> createState() => _CreateEditUserSheetState();
}

class _CreateEditUserSheetState extends State<CreateEditUserSheet> {
  late String _selectedEmployee;
  late String _workEmail;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isAccountActive = true;

  final Map<String, String> _employeeEmails = {
    'Aarav Mehta': 'aarav@company.com',
    'Maya Shah': 'maya@company.com',
    'Rohan Patel': 'rohan@company.com',
    'Nisha Rao': 'nisha@company.com',
    'Elena Rostova': 'elena.rostova@enterprise.odoo.com',
  };

  final Map<String, String> _employeeIds = {
    'Aarav Mehta': 'EMP-4091',
    'Maya Shah': 'EMP-4092',
    'Rohan Patel': 'EMP-4093',
    'Nisha Rao': 'EMP-4094',
    'Elena Rostova': 'EMP-4095',
  };

  final Map<String, String> _employeeDepts = {
    'Aarav Mehta': 'Payroll Specialist • Finance',
    'Maya Shah': 'HR Specialist • People Ops',
    'Rohan Patel': 'Supply Chain • Logistics',
    'Nisha Rao': 'Payroll Lead • Comp & Benefits',
    'Elena Rostova': 'Software Architect • Engineering',
  };

  final List<Map<String, dynamic>> _availableRoles = [
    {
      'id': 'employee',
      'title': 'Employee',
      'subtitle': 'Self-service leave requests & attendance clocking',
      'icon': Icons.person_outline,
    },
    {
      'id': 'hr_manager',
      'title': 'HR Manager',
      'subtitle': 'Full personnel profile & time-off management',
      'icon': Icons.badge_outlined,
    },
    {
      'id': 'payroll_user',
      'title': 'HR Payroll User',
      'subtitle': 'Payrun creation, timesheet approvals & payslip calculation',
      'icon': Icons.payments_outlined,
    },
    {
      'id': 'payroll_admin',
      'title': 'HR Payroll Admin',
      'subtitle': 'Salary rules, allowance structures & tax tables',
      'icon': Icons.account_balance_outlined,
    },
    {
      'id': 'sysadmin',
      'title': 'System Admin',
      'subtitle': 'Global ERP control, audit logs & security policies',
      'icon': Icons.shield_outlined,
    },
  ];

  final Set<String> _selectedRoleIds = {'payroll_user'};

  @override
  void initState() {
    super.initState();
    _selectedEmployee = widget.initialEmployee ?? 'Aarav Mehta';
    _workEmail = widget.initialEmail ?? _employeeEmails[_selectedEmployee] ?? 'aarav@company.com';
    _passwordController = TextEditingController(text: 'K9#m\$X8p@vQ2');

    if (widget.initialRole != null) {
      final roleLower = widget.initialRole!.toLowerCase();
      if (roleLower.contains('admin') && roleLower.contains('sys')) {
        _selectedRoleIds.clear();
        _selectedRoleIds.add('sysadmin');
      } else if (roleLower.contains('payroll admin')) {
        _selectedRoleIds.clear();
        _selectedRoleIds.add('payroll_admin');
      } else if (roleLower.contains('payroll user')) {
        _selectedRoleIds.clear();
        _selectedRoleIds.add('payroll_user');
      } else if (roleLower.contains('hr manager') || roleLower.contains('time off admin')) {
        _selectedRoleIds.clear();
        _selectedRoleIds.add('hr_manager');
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _generateStrongPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#\$%&*';
    final random = Random.secure();
    final newPass = List.generate(14, (index) => chars[random.nextInt(chars.length)]).join();

    setState(() {
      _passwordController.text = newPass;
      _obscurePassword = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 2000),
        content: Text('✨ High-entropy temporary password generated!'),
      ),
    );
  }

  void _onEmployeeChanged(String? newEmp) {
    if (newEmp == null) return;
    setState(() {
      _selectedEmployee = newEmp;
      _workEmail = _employeeEmails[newEmp] ?? '$newEmp@company.com'.toLowerCase().replaceAll(' ', '.');
    });
  }

  void _toggleRole(String roleId) {
    setState(() {
      if (_selectedRoleIds.contains(roleId)) {
        if (_selectedRoleIds.length > 1) {
          _selectedRoleIds.remove(roleId);
        }
      } else {
        _selectedRoleIds.add(roleId);
      }
    });
  }

  void _handleSave() {
    final primaryRoleTitle = _availableRoles.firstWhere(
      (r) => _selectedRoleIds.contains(r['id']),
      orElse: () => _availableRoles[2],
    )['title'] as String;

    final empName = _selectedEmployee;

    widget.onSave?.call({
      'employee': _selectedEmployee,
      'email': _workEmail,
      'password': _passwordController.text,
      'role': primaryRoleTitle,
      'allRoles': _selectedRoleIds.toList(),
      'isActive': _isAccountActive,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF004A31),
        behavior: SnackBarBehavior.floating,
        content: Text('✓ User access permissions saved for $empName'),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1C3CA),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create / Edit User',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF131B2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF00696E)),
                            const SizedBox(width: 4),
                            Text(
                              'RBAC & Identity Provisioning',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00696E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAEDFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.close, size: 18, color: Color(0xFF131B2E)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Policy Callout Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info, color: Color(0xFF714B67), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF131B2E), height: 1.35),
                            children: const [
                              TextSpan(text: 'ERP Policy: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF714B67))),
                              TextSpan(text: 'User accounts are separate from Employee records, but must be linked to an employee to assign operational roles and record ownership.'),
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

          const SizedBox(height: 14),

          // Scrollable Form Fields
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field 1: Employee Select Searchable Dropdown
                  _buildEmployeeField(),

                  const SizedBox(height: 16),

                  // Field 2: Work Email (Auto-populated with Lock Badge)
                  _buildWorkEmailField(),

                  const SizedBox(height: 16),

                  // Field 3: Temporary Password & Generator
                  _buildPasswordField(),

                  const SizedBox(height: 16),

                  // Field 4: Assign Roles (Multi-Select Group)
                  _buildRolesSection(),

                  const SizedBox(height: 16),

                  // Field 5: Account Status Toggle
                  _buildAccountStatusToggle(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Sticky Dual Actions Ribbon
          _buildBottomActionRibbon(),
        ],
      ),
    );
  }

  Widget _buildEmployeeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                text: 'Employee ',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                children: const [
                  TextSpan(text: '*', style: TextStyle(color: Color(0xFFBA1A1A))),
                ],
              ),
            ),
            Text(
              'PAYROLL READY',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00696E),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF714B67),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCGX3OR1aP7-CHa7_fktlHkQU__rI1qY-zVyWRuxx0dH0gRx_OJWGA6bNBIIgF-Hrw5glOxZnKwUJZuJG6bVvDxm22ygnO_hIbkAQuemJubOFGaj1lh99VGicObPrbd_lZcZe80DDlhksALAU8g6pghQdoSlpaLKRVqZ2R7txtqdUR-QUpjeNt1s8kCVgkKyc0z-Q00a1SuFHACJi1NeBaaVWqAeY1b7uQoESMnXVIKSRJL0Y3n9BbW',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          _selectedEmployee.split(' ').map((e) => e[0]).take(2).join(),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF006443),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedEmployee,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
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
                            'ID: ${_employeeIds[_selectedEmployee] ?? 'EMP-4091'}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _employeeDepts[_selectedEmployee] ?? 'Payroll Specialist • Finance',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF4E444A),
                      ),
                    ),
                  ],
                ),
              ),
              // Popup dropdown
              PopupMenuButton<String>(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                icon: const Icon(Icons.unfold_more, color: Color(0xFF4E444A)),
                onSelected: _onEmployeeChanged,
                itemBuilder: (context) => _employeeEmails.keys.map((emp) {
                  return PopupMenuItem(
                    value: emp,
                    child: Text(
                      emp,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                text: 'Work Email ',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                children: const [
                  TextSpan(text: '*', style: TextStyle(color: Color(0xFFBA1A1A))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6FFBBE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync, size: 12, color: Color(0xFF002113)),
                  const SizedBox(width: 4),
                  Text(
                    'Auto-synced from HR',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF002113),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E7FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.alternate_email, size: 18, color: Color(0xFF4E444A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _workEmail,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: const Color(0xFF131B2E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.check_circle, size: 18, color: Color(0xFF006443)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Temporary Password ',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            children: const [
              TextSpan(text: '*', style: TextStyle(color: Color(0xFFBA1A1A))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Password input
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          letterSpacing: _obscurePassword ? 2.0 : 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                        color: const Color(0xFF80747A),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Generate Strong button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF92EFF5),
                foregroundColor: const Color(0xFF006E73),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                elevation: 0,
              ),
              onPressed: _generateStrongPassword,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text(
                'Generate Strong',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'User will be prompted to reset upon their initial authentication.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: const Color(0xFF4E444A),
          ),
        ),
      ],
    );
  }

  Widget _buildRolesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: TextSpan(
                text: 'Assign Roles & Permissions ',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                children: const [
                  TextSpan(text: '*', style: TextStyle(color: Color(0xFFBA1A1A))),
                ],
              ),
            ),
            Text(
              '${_selectedRoleIds.length} Selected',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF4E444A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: _availableRoles.map((role) {
              final isChecked = _selectedRoleIds.contains(role['id']);
              return InkWell(
                onTap: () => _toggleRole(role['id'] as String),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChecked ? const Color(0xFFFFD7F1).withValues(alpha: 0.3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Checkbox box
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isChecked ? const Color(0xFF714B67) : const Color(0xFFE2E7FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: isChecked
                            ? const Center(
                                child: Icon(Icons.check, size: 15, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      // Role title & subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  role['title'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: isChecked ? FontWeight.bold : FontWeight.w600,
                                    color: isChecked ? const Color(0xFF714B67) : const Color(0xFF131B2E),
                                  ),
                                ),
                                if (isChecked) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF714B67),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Active',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role['subtitle'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: const Color(0xFF4E444A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        role['icon'] as IconData,
                        size: 18,
                        color: isChecked ? const Color(0xFF714B67) : const Color(0xFF80747A),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountStatusToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Account Status',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _isAccountActive ? const Color(0xFF6FFBBE).withValues(alpha: 0.3) : const Color(0xFFE2E7FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isAccountActive ? 'Active' : 'Disabled',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isAccountActive ? const Color(0xFF004A31) : const Color(0xFF4E444A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'User can authenticate via SSO, OAuth & Work Email credentials.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF4E444A),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAccountActive,
            activeTrackColor: const Color(0xFF006443),
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD1C3CA),
            onChanged: (val) {
              setState(() {
                _isAccountActive = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionRibbon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Discard Button (1/3)
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFEAEDFF),
                  foregroundColor: const Color(0xFF131B2E),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Discard',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Save User Access Button (2/3)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF714B67),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _handleSave,
                icon: const Icon(Icons.save, size: 18),
                label: Text(
                  'Save User Access',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
