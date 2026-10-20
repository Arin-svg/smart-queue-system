import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import '../services/device_push_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool marking = false;
  final Set<int> attempted = {};
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final rows = c.rows('notifications');
    final ids = rows
        .where((n) => n['notification_status'] != 'read')
        .map((n) => n['notification_id'] as int)
        .where((id) => !attempted.contains(id))
        .toList();
    if (ClinicScope.of(context).role == 'patient' &&
        !marking &&
        ids.isNotEmpty) {
      marking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        attempted.addAll(ids);
        try {
          await c.api.post('/notifications/read', {'ids': ids});
          for (final id in ids) {
            try {
              await DevicePushService.channel.invokeMethod('cancel', {'notification_id': '$id'});
            } catch (_) { /* Device notifications are unavailable on other platforms. */ }
          }
          await c.refresh();
        } catch (_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not mark alerts as read. Tap a message to retry.',
                ),
              ),
            );
        } finally {
          if (mounted) setState(() => marking = false);
        }
      });
    }
    return ClinicPage(
      title: 'Notifications',
      children: [
        if (rows.isEmpty)
          const EmptyState(
            'No notifications yet',
            'Queue updates and appointment reminders will appear here.',
            icon: Icons.notifications_none,
          ),
        ...rows.map(
          (n) => Panel(
            tint: n['notification_status'] == 'read'
                ? Colors.white
                : const Color(0xFFECFCF6),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(
                display(n['notification_title']),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${display(n['notification_message'])}\n${display(n['sent_at'], '')}',
              ),
              trailing: n['notification_status'] == 'read'
                  ? null
                  : const Icon(Icons.circle, size: 8, color: Colors.teal),
              onTap: c.saving || n['notification_status'] == 'read'
                  ? null
                  : () => perform(
                      context,
                      () => c.submit(
                        '/notifications/${n['notification_id']}/read',
                        {},
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
