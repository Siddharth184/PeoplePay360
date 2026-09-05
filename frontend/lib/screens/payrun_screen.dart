import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/payslip_pdf_dialog.dart';

class PayrunScreen extends StatefulWidget {
  const PayrunScreen({super.key});

  @override
  State<PayrunScreen> createState() => _PayrunScreenState();
}

class _PayrunScreenState extends State<PayrunScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payrun & Payslip Wizard', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              // 2-Step Payrun Stepper Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStepIndicator(0, '1. Scope & Period'),
                          const Expanded(child: Divider(indent: 8, endIndent: 8)),
                          _buildStepIndicator(1, '2. Pre-Flight Anomaly Check'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_currentStep == 0) _buildStep1Content() else _buildStep2Content(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Generated Payslips Ledger', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: MockDataService.payslips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final slip = MockDataService.payslips[index];

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.odooAubergine,
                        child: Icon(Icons.receipt_long, color: Colors.white),
                      ),
                      title: Text('${slip.employeeName} (${slip.refCode})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Period: ${slip.periodStart} to ${slip.periodEnd}\nNet Wage: ₹${slip.netAmount.toStringAsFixed(2)}'),
                      trailing: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.odooTeal, foregroundColor: Colors.white),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PayslipPdfDialog(payslip: slip),
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('PDF'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isActive ? AppTheme.odooAubergine : Colors.grey.withOpacity(0.3),
          child: Text('${stepIndex + 1}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ],
    );
  }

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Pay Period: August 2026', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: 'All Departments',
          decoration: const InputDecoration(labelText: 'Department Scope', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'All Departments', child: Text('All Departments (142 Employees)')),
            DropdownMenuItem(value: 'Finance & Tech Ops', child: Text('Finance & Tech Ops (24 Employees)')),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.odooAubergine, foregroundColor: Colors.white),
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('Next: Pre-Flight Anomaly Check →'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.amberWarning.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppTheme.amberWarning),
              SizedBox(width: 10),
              Expanded(
                child: Text('0 Critical Anomalies Found. Ready to compute payroll batch.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('← Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldSuccess, foregroundColor: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🎉 Payrun Computed! 142 Payslips generated & verified.')),
                  );
                },
                child: const Text('Confirm Payrun'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
