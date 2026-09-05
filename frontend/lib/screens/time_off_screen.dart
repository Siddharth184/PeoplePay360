import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';

class TimeOffScreen extends StatefulWidget {
  const TimeOffScreen({super.key});

  @override
  State<TimeOffScreen> createState() => _TimeOffScreenState();
}

class _TimeOffScreenState extends State<TimeOffScreen> {
  void _openRequestBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request Time Off',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: 'Paid Time Off (PTO)',
                decoration: const InputDecoration(labelText: 'Time Off Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Paid Time Off (PTO)', child: Text('Paid Time Off (PTO)')),
                  DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
                  DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '2026-09-15',
                      decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: '2026-09-18',
                      decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: 'Family event trip',
                decoration: const InputDecoration(labelText: 'Reason / Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.odooAubergine, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Time Off Request Submitted for Manager Approval')),
                    );
                  },
                  child: const Text('Submit Request'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.odooAubergine,
        foregroundColor: Colors.white,
        onPressed: _openRequestBottomSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time Off & Leave Balance', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              // Balance Progress Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Paid Time Off (PTO) Allocation', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('14 / 20 Days Left', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.odooTeal)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearPercentIndicator(
                        lineHeight: 12.0,
                        percent: 14.0 / 20.0,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        progressColor: AppTheme.odooTeal,
                        barRadius: const Radius.circular(6),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Allocated: 20.0 Days', style: TextStyle(fontSize: 12)),
                          Text('Taken: 6.0 Days', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Leave Requests & Approvals', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: MockDataService.timeOffRequests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final req = MockDataService.timeOffRequests[index];
                  final isPending = req.status == 'PENDING';

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPending ? AppTheme.amberWarning.withValues(alpha: 0.2) : AppTheme.emeraldSuccess.withValues(alpha: 0.2),
                        child: Icon(
                          isPending ? Icons.pending_actions : Icons.check,
                          color: isPending ? AppTheme.amberWarning : AppTheme.emeraldSuccess,
                        ),
                      ),
                      title: Text(req.typeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${req.startDate} to ${req.endDate} (${req.daysCount} days)\nReason: ${req.reason}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isPending ? AppTheme.amberWarning : AppTheme.emeraldSuccess).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          req.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPending ? AppTheme.amberWarning : AppTheme.emeraldSuccess,
                          ),
                        ),
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
}
