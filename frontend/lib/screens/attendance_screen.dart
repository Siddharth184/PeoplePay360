import 'package:flutter/material.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dynamic_island_pill.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _filter = 'ALL';

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
              Center(
                child: DynamicIslandPill(
                  onPunchTapped: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚡ Attendance Status Updated via Biometrics'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Attendance & Presence',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              // Stats Ribbon
              Row(
                children: [
                  _buildStatCard('Present', '22', AppTheme.emeraldSuccess),
                  const SizedBox(width: 8),
                  _buildStatCard('Late', '1', AppTheme.amberWarning),
                  const SizedBox(width: 8),
                  _buildStatCard('On Leave', '0', AppTheme.odooTeal),
                  const SizedBox(width: 8),
                  _buildStatCard('Absent', '0', AppTheme.crimsonDanger),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Attendance Logs', style: Theme.of(context).textTheme.titleMedium),
                  DropdownButton<String>(
                    value: _filter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Logs')),
                      DropdownMenuItem(value: 'PRESENT', child: Text('Present')),
                      DropdownMenuItem(value: 'LATE', child: Text('Late')),
                    ],
                    onChanged: (val) => setState(() => _filter = val!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: MockDataService.attendances.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = MockDataService.attendances[index];
                  final isPresent = item.status == 'PRESENT';

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (isPresent ? AppTheme.emeraldSuccess : AppTheme.amberWarning).withOpacity(0.15),
                        child: Icon(
                          isPresent ? Icons.check_circle_outline : Icons.access_time,
                          color: isPresent ? AppTheme.emeraldSuccess : AppTheme.amberWarning,
                        ),
                      ),
                      title: Text(
                        'Date: ${item.dateStr}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'In: ${item.checkInTime}  •  Out: ${item.checkOutTime ?? 'Active'}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isPresent ? AppTheme.emeraldSuccess : AppTheme.amberWarning).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPresent ? AppTheme.emeraldSuccess : AppTheme.amberWarning,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.workedHours} hrs',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
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

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
