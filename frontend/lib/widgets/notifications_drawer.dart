import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../screens/escalation_ticket_screen.dart';

class NotificationsDrawer extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const NotificationsDrawer({super.key, this.onNavigateTab});

  static void show(BuildContext context, {Function(int)? onNavigateTab}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationsDrawer(onNavigateTab: onNavigateTab),
    );
  }

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Escalations', 'Payrun', 'Attendance'];

  @override
  void initState() {
    super.initState();
    NotificationService.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: NotificationService.notificationsNotifier,
      builder: (context, notifications, _) {
        final filteredNotifications = notifications.where((n) {
          if (_selectedFilterIndex == 0) return true;
          if (_selectedFilterIndex == 1) return n['category'] == 'Escalations';
          if (_selectedFilterIndex == 2) return n['category'] == 'Payrun';
          if (_selectedFilterIndex == 3) return n['category'] == 'Attendance';
          return true;
        }).toList();

        final unreadCount = notifications.where((n) => n['isUnread'] == true).length;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.notifications_active, color: AppTheme.odooAubergine),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Notifications Inbox',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.odooTeal,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unreadCount new',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            NotificationService.markAllRead();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All notifications marked as read')),
                            );
                          },
                          child: const Text('Mark Read', style: TextStyle(fontSize: 11.5)),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                    final filterName = _filters[index];
                    int count = 0;
                    if (index == 0) {
                      count = notifications.length;
                    } else {
                      count = notifications.where((n) => n['category'] == filterName).length;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$filterName ($count)'),
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
                          final isUnread = notif['isUnread'] == true;

                          return Material(
                            color: isUnread ? AppTheme.surfaceContainerLow : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                NotificationService.markRead(notif['id']);
                                Navigator.pop(context);

                                if (notif['category'] == 'Escalations' || notif['ticket'] != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EscalationTicketScreen(
                                        ticket: notif['ticket'],
                                      ),
                                    ),
                                  );
                                } else if (widget.onNavigateTab != null && notif['tabIndex'] != null) {
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
                                        color: notif['bg'] ?? Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        notif['icon'] ?? Icons.notifications,
                                        color: notif['color'] ?? AppTheme.odooAubergine,
                                        size: 22,
                                      ),
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
                                                  notif['title'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: AppTheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (isUnread)
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
                                            notif['subtitle'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.onSurfaceVariant,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            notif['time'] ?? '',
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
                      onPressed: () {
                        NotificationService.clearAll();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifications inbox cleared')),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                      label: const Text('Clear All Notifications', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
