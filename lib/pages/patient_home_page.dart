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
    final clinicStatus = c.data['clinic_status'] as Map?;
    final statusTime = DateTime.tryParse(
      '${clinicStatus?['updated_at']}',
    )?.toUtc().add(const Duration(hours: 8));
    final unread = c
        .rows('notifications')
        .where((n) => n['notification_status'] != 'read')
        .length;

    return ClinicPage(
      title: 'Home',
      action: IconButton(
        tooltip: unread > 0 ? '$unread unread alerts' : 'View alerts',
        onPressed: () => scope.navigate('Alerts'),
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ),
      children: [
        Text(
          _dateLabel(context, today).toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: Color(0xFF748780),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hello, ${display(c.profile['name'], 'there')}',
          style: const TextStyle(
            fontSize: 28,
            letterSpacing: -.7,
            fontWeight: FontWeight.w700,
            color: Color(0xFF163E35),
          ),
        ),
        const SizedBox(height: 6),

        _HomeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading(Icons.monitor_heart_outlined, 'Clinic right now'),
              const SizedBox(height: 6),
              const Text(
                'Activity across all departments',
                style: TextStyle(fontSize: 12, color: Color(0xFF748780)),
              ),
              const SizedBox(height: 18),
              if (clinicStatus == null)
                const Text(
                  'Clinic activity is not available yet. Pull down to refresh.',
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final metric in [
                        (
                          'Waiting',
                          clinicStatus['waiting'],
                          Icons.groups_outlined,
                          const Color(0xFF007E69),
                        ),
                        (
                          'In consultation',
                          clinicStatus['in_consultation'],
                          Icons.medical_services_outlined,
                          const Color(0xFF5367B5),
                        ),
                        (
                          'Completed today',
                          clinicStatus['completed_today'],
                          Icons.task_alt_rounded,
                          const Color(0xFF8B651F),
                        ),
                      ])
                        Container(
                          width: constraints.maxWidth < 280
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 16) / 3,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: metric.$4.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(metric.$3, color: metric.$4, size: 21),
                              const SizedBox(height: 10),
                              Text(
                                '${metric.$2 ?? '—'}',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  color: metric.$4,
                                ),
                              ),
                              Text(
                                metric.$1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  c.error != null
                      ? 'Showing the last update. Connection interrupted.'
                      : statusTime == null
                      ? 'Updates automatically while the app is open.'
                      : 'Updated ${statusTime.hour.toString().padLeft(2, '0')}:${statusTime.minute.toString().padLeft(2, '0')} MYT',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF748780),
                  ),
                ),
              ],
            ],
          ),
        ),
        _HomeCard(
          featured: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading(
                Icons.confirmation_number_outlined,
                'Your queue',
                light: true,
              ),
              const SizedBox(height: 16),
              if (queue == null) ...[
                const Text(
                  'No active queue',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Arriving at the clinic? Scan the QR code to get your place in line.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF007E69),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: StatusBadge('${queue['queue_status']}'),
                ),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => scope.navigate('My Queue'),
                  child: const Text('View queue details'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        _HomeCard(
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
  const _Heading(this.icon, this.title, {this.light = false});
  final bool light;
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        color: light ? Colors.white70 : const Color(0xFF008B73),
        size: 22,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: light ? Colors.white : const Color(0xFF163E35),
          ),
        ),
      ),
    ],
  );
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child, this.featured = false});
  final Widget child;
  final bool featured;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: featured ? null : Colors.white,
      gradient: featured
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00A88B), Color(0xFF007B69)],
            )
          : null,
      borderRadius: BorderRadius.circular(24),
      border: featured ? null : Border.all(color: const Color(0xFFE5EDE9)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF164D3D).withValues(alpha: .05),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(
        color: featured
            ? Colors.white.withValues(alpha: .9)
            : const Color(0xFF50675F),
        height: 1.45,
      ),
      child: child,
    ),
  );
}
