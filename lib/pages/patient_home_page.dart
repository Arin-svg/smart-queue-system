import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ClinicScope.of(context);
    final c = scope.controller;
    // Appointment dates belong to the clinic in Malaysia, regardless of device zone.
    final clinicNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = clinicNow.toIso8601String().substring(0, 10);
    final appointments =
        c.rows('appointments').where((a) {
          final date = '${a['appointment_date']}';
          return ['pending', 'confirmed'].contains(a['appointment_status']) &&
              date.compareTo(today) >= 0;
        }).toList()..sort(
          (a, b) => '${a['appointment_date']} ${a['appointment_time']}'
              .compareTo('${b['appointment_date']} ${b['appointment_time']}'),
        );
    final appointment = appointments.isEmpty ? null : appointments.first;
    final queues = c.activeQueues;
    final queue = queues.isEmpty ? null : queues.first;
    final unread = c
        .rows('notifications')
        .where((n) => n['notification_status'] != 'read')
        .length;

    return ClinicPage(
      title: 'Home',
      children: [
        Text(
          'Hello, ${display(c.profile['name'], 'there')}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your clinic visit, at a glance.',
          style: TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 22),
        Panel(
          tint: const Color(0xFFE9FAF5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading(Icons.confirmation_number_outlined, 'Your queue'),
              const SizedBox(height: 16),
              if (queue == null) ...[
                const Text(
                  'No active queue',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan the clinic QR code when you arrive to join the queue.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => scope.navigate('Scan'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan clinic QR'),
                ),
              ] else ...[
                Text(
                  display(queue['queue_number']),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                StatusBadge('${queue['queue_status']}'),
                const SizedBox(height: 12),
                Text(display(queue['department_name'], 'Clinic visit')),
                if (queue['queue_status'] == 'called')
                  const Text(
                    'It is your turn. Please proceed to your assigned room.',
                  )
                else if (queue['queue_status'] == 'in_consultation')
                  const Text('Your consultation is in progress.')
                else if (queue['estimated_waiting_time'] != null)
                  Text(
                    'Estimated wait: ${queue['estimated_waiting_time']} min',
                  ),
                if (queue['room_name'] != null)
                  Text('Room: ${queue['room_name']}'),
                TextButton(
                  onPressed: () => scope.navigate('My Queue'),
                  child: const Text('View queue details'),
                ),
              ],
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading(Icons.calendar_month_outlined, 'Next appointment'),
              const SizedBox(height: 16),
              if (appointment == null) ...[
                const Text(
                  'No upcoming appointments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Plan your next visit by booking an available clinic slot.',
                ),
              ] else ...[
                Text(
                  _dateLabel(context, '${appointment['appointment_date']}'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${appointment['appointment_time']}'
                      .split(':')
                      .take(2)
                      .join(':'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                StatusBadge('${appointment['appointment_status']}'),
                const SizedBox(height: 12),
                InfoLine(
                  Icons.local_hospital_outlined,
                  display(appointment['department_name']),
                ),
                InfoLine(
                  Icons.person_outline,
                  display(appointment['doctor_name'], 'Any available doctor'),
                ),
                const SizedBox(height: 8),
                Text(
                  appointment['appointment_status'] == 'pending'
                      ? 'Awaiting staff verification. Your appointment is not confirmed yet.'
                      : 'Confirmed. Scan the clinic QR code when you arrive.',
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => scope.navigate('Appts'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  appointment == null
                      ? 'Book an appointment'
                      : 'Manage appointments',
                ),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickAction(
                    onPressed: () => scope.navigate('Scan'),
                    icon: Icons.qr_code_scanner,
                    label: 'QR Scan',
                    color: Colors.teal,
                  ),
                  _QuickAction(
                    onPressed: () => scope.navigate('Appts'),
                    icon: Icons.calendar_month,
                    label: 'Book Appt',
                    color: Colors.orange,
                  ),
                  _QuickAction(
                    onPressed: () => scope.navigate('History'),
                    icon: Icons.history,
                    label: 'History',
                    color: Colors.indigo,
                  ),
                  _QuickAction(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Need assistance?'),
                        content: const Text(
                          'Please visit the registration counter. Staff can help with queue registration, verification and appointment check-in.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    icon: Icons.support_agent,
                    label: 'Support',
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => scope.navigate('Alerts'),
          icon: const Icon(Icons.notifications_none),
          label: Text(unread > 0 ? 'Alerts ($unread unread)' : 'View alerts'),
        ),
      ],
    );
  }

  String _dateLabel(BuildContext context, String value) {
    final date = DateTime.tryParse(value);
    return date == null
        ? value
        : MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.icon, this.title);
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ),
  );
}
