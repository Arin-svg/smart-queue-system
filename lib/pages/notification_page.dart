import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final rows = c.rows('notifications');
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
