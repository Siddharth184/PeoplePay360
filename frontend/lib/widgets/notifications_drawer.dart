import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationsDrawer extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const NotificationsDrawer({super.key, this.onNavigateTab});

  static void show(BuildContext context, {Function(int)? onNavigateTab}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationsDrawer(onNavigateTab: onNavigateTab),
    );
  }

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All (4)', 'Escalations (1)', 'Payrun (1)', 'Attendance (2)'];

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'n-1',
      'icon': Icons.warning_amber_rounded,
      'color': Colors.amber.shade700,
      'bg': Colors.amber.shade50,
      'title': 'HR Escalation ESC/2026/0001',
      'subtitle': 'Uncertain Leave Policy query auto-routed to Sara Khan (HR Director). SLA: 8h remaining.',
      'time': '10:44 AM',
      'tabIndex': 5, // Copilot / Escalations
      'category': 'Escalations',
      'isUnread': true,
    },
    {
      'id': 'n-2',
      'icon': Icons.no_accounts_outlined,
      'color': AppTheme.odooRed,
      'bg': const Color(0xFFFFDAD6),
      'title': 'Payrun Pre-Flight Anomaly',
      'subtitle': '2 active employees (Sara Khan, Neha Patel) have unverified bank details in Feb 2026 Payrun.',
      'time': '09:30 AM',
      'tabIndex': 4, // Payrun
      'category': 'Payrun',
      'isUnread': true,
    },
    {
      'id': 'n-3',
      'icon': Icons.verified_outlined,
      'color': AppTheme.odooGreen,
      'bg': const Color(0xFFE6F4EA),
      'title': 'Attendance Punch Verified',
      'subtitle': 'Morning check-in recorded at 09:05 AM (Mumbai Hub). Shift progress: 86%.',
      'time': '09:05 AM',
      'tabIndex': 1, // Attendance
      'category': 'Attendance',
      'isUnread': false,
    },
    {
      'id': 'n-4',
      'icon': Icons.flight_takeoff_rounded,
      'color': AppTheme.odooTeal,
      'bg': const Color(0xFFE0F7FA),
      'title': 'Time Off Allocation Updated',
      'subtitle': '14 days Paid Time Off balance verified for FY 2026.',
      'time': 'Yesterday',
      'tabIndex': 2, // Time Off
      'category': 'Attendance',
      'isUnread': false,
    },
  ];

  void _markAllRead() {
    setState(() {
      for (var n in _notifications) {
        n['isUnread'] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  void _clearAll() {
    setState(() {
      _notifications.clear();
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications inbox cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _notifications.where((n) {
      if (_selectedFilterIndex == 0) return true;
      if (_selectedFilterIndex == 1) return n['category'] == 'Escalations';
      if (_selectedFilterIndex == 2) return n['category'] == 'Payrun';
      if (_selectedFilterIndex == 3) return n['category'] == 'Attendance';
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Grabber Pill
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppTheme.odooAubergine),
                    const SizedBox(width: 8),
                    Text(
                      'HR Operations Inbox',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _markAllRead,
                      child: const Text('Mark Read', style: TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Filter Chips Rail
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(_filters.length, (index) {
                final isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filters[index]),
                    selected: isSelected,
                    selectedColor: AppTheme.odooAubergine,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilterIndex = index);
                    },
                  ),
                );
              }),
            ),
          ),

          const Divider(height: 24),

          // List of Notifications
          Expanded(
            child: filteredNotifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No notifications found', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredNotifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = filteredNotifications[index];
                      return Material(
                        color: notif['isUnread'] ? AppTheme.surfaceContainerLow : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() => notif['isUnread'] = false);
                            Navigator.pop(context);
                            if (widget.onNavigateTab != null && notif['tabIndex'] != null) {
                              widget.onNavigateTab!(notif['tabIndex']);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: notif['bg'],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(notif['icon'], color: notif['color'], size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif['title'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppTheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          if (notif['isUnread'])
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppTheme.odooTeal,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif['subtitle'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.onSurfaceVariant,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        notif['time'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
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
                    },
                  ),
          ),

          // Footer
          if (filteredNotifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  label: const Text('Clear All Notifications', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
