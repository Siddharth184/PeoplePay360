import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/smart_button.dart';
import '../widgets/payslip_pdf_dialog.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const EmployeeProfileScreen({super.key, this.onNavigateTab});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final emp = MockDataService.currentEmployee;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Profile Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppTheme.odooAubergine,
                        child: Text(
                          emp.name.split(' ').map((e) => e[0]).join(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              emp.jobTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.odooTeal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Dept: ${emp.department}', style: Theme.of(context).textTheme.bodyMedium),
                            Text('Manager: ${emp.managerName}', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Smart Buttons Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SmartButton(
                      icon: Icons.flight_takeoff,
                      label: 'Time Off',
                      count: '${emp.timeOffBalance} Days',
                      onTap: () => widget.onNavigateTab?.call(2), // Time Off tab
                    ),
                    const SizedBox(width: 8),
                    SmartButton(
                      icon: Icons.description_outlined,
                      label: 'Contracts',
                      count: '${emp.activeContractsCount} Active',
                      color: AppTheme.odooAubergine,
                      onTap: () => widget.onNavigateTab?.call(3), // Contracts tab
                    ),
                    const SizedBox(width: 8),
                    SmartButton(
                      icon: Icons.fingerprint,
                      label: 'Attendance',
                      count: '${emp.attendancesCount} Days',
                      color: AppTheme.emeraldSuccess,
                      onTap: () => widget.onNavigateTab?.call(1), // Attendance tab
                    ),
                    const SizedBox(width: 8),
                    SmartButton(
                      icon: Icons.payments_outlined,
                      label: 'Payslips',
                      count: '${emp.payslipsCount} Slips',
                      color: AppTheme.amberWarning,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => PayslipPdfDialog(payslip: MockDataService.payslips.first),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Tabs Navigation
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.odooAubergine,
                unselectedLabelColor: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                indicatorColor: AppTheme.odooAubergine,
                tabs: const [
                  Tab(text: 'Public Info'),
                  Tab(text: 'Work Info'),
                  Tab(text: 'Private Info'),
                  Tab(text: 'HR Settings'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPublicInfoTab(),
                    _buildWorkInfoTab(),
                    _buildPrivateInfoTab(),
                    _buildHrSettingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicInfoTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Work Email', emp.email, Icons.email_outlined),
            const Divider(),
            _buildDetailRow('Work Phone', emp.workPhone, Icons.phone_outlined),
            const Divider(),
            _buildDetailRow('Work Location', 'Mumbai HQ (Floor 4)', Icons.location_on_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkInfoTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Manager', emp.managerName, Icons.supervisor_account),
            const Divider(),
            _buildDetailRow('Working Schedule', 'Standard 40 Hours/Week', Icons.schedule),
            const Divider(),
            _buildDetailRow('Timezone', 'Asia/Kolkata (IST)', Icons.public),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateInfoTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Address', 'Bandra West, Mumbai, MH', Icons.home_outlined),
            const Divider(),
            _buildDetailRow('Bank Account', 'HDFC Bank (•••• 4321)', Icons.account_balance),
            const Divider(),
            _buildDetailRow('Emergency Contact', '+91 91234 56789 (Spouse)', Icons.contact_emergency),
          ],
        ),
      ),
    );
  }

  Widget _buildHrSettingsTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Employee Code', 'EMP/2026/001', Icons.qr_code),
            const Divider(),
            _buildDetailRow('Badge ID', 'BDG-9942', Icons.badge),
            const Divider(),
            _buildDetailRow('System User ID', 'usr-uuid-8832', Icons.security),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.odooAubergine),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
