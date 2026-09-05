import 'package:flutter/material.dart';
import 'api_client.dart';

class NotificationService {
  static final ValueNotifier<List<Map<String, dynamic>>> notificationsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static Future<void> fetchNotifications() async {
    final res = await ApiClient.get<List<Map<String, dynamic>>>(
      '/users/notifications',
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );

    if (res.isSuccess && res.data != null) {
      final parsed = res.data!.map((n) {
        return {
          'id': n['id']?.toString() ?? '',
          'kind': n['kind']?.toString() ?? 'SYSTEM',
          'title': n['title']?.toString() ?? 'Notification',
          'subtitle': n['body']?.toString() ?? '',
          'time': n['created_at'] != null && n['created_at'].toString().length >= 10
              ? n['created_at'].toString().substring(0, 10)
              : 'Recent',
          'isUnread': n['is_read'] != true,
          'category': n['kind']?.toString() ?? 'General',
        };
      }).toList();
      notificationsNotifier.value = parsed;
    }
  }

  static void addNotification(Map<String, dynamic> notif) {
    final current = List<Map<String, dynamic>>.from(notificationsNotifier.value);
    current.insert(0, notif);
    notificationsNotifier.value = current;
  }

  static Future<void> markRead(String id) async {
    final current = List<Map<String, dynamic>>.from(notificationsNotifier.value);
    final index = current.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      current[index] = Map<String, dynamic>.from(current[index])..['isUnread'] = false;
      notificationsNotifier.value = current;
    }
    await ApiClient.post('/users/notifications/$id/read');
  }

  static Future<void> markAllRead() async {
    final current = List<Map<String, dynamic>>.from(notificationsNotifier.value);
    for (var n in current) {
      n['isUnread'] = false;
    }
    notificationsNotifier.value = current;
    await ApiClient.post('/users/notifications/read-all');
  }

  static void clearAll() {
    notificationsNotifier.value = [];
  }
}
