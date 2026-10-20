import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'monitor_page.dart';

class VerifyPage extends StatelessWidget {
  const VerifyPage({super.key, this.queueId});
  final String? queueId;
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final queues = c.orderedQueues
        .where((q) => q['queue_status'] == 'waiting')
        .toList();
    if (queueId != null) {
      queues.sort(
        (a, b) => ('${a['queue_id']}' == queueId ? 0 : 1).compareTo(
          '${b['queue_id']}' == queueId ? 0 : 1,
        ),
      );
    }
    final appointments = c
        .rows('appointments')
        .where((a) => a['appointment_status'] == 'pending')
        .toList();
    return ClinicPage(
      title: 'Staff',
      children: [
        const StaffSummary(),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text('Verify patients before assigning'),
        ),
        if (queues.isEmpty && appointments.isEmpty)
          const EmptyState(
            'All caught up!',
            'No patients waiting for verification',
          ),
        ...queues.map(
          (q) => QueueCard(
            q,
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: c.saving
                      ? null
                      : () async {
                          if (await confirm(
                                context,
                                'Verify Patient',
                                'Confirm the identity of ${q['patient_name']} (${q['user_identifier']})?',
                              ) &&
                              context.mounted) {
                            await perform(
                              context,
                              () => c.submit('/queues/${q['queue_id']}', {
                                'action': 'verify',
                              }),
                              success:
                                  'Queue ${q['queue_number']} has been verified.',
                            );
                          }
                        },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verify Patient'),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Appointments Awaiting Verification',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (appointments.isEmpty)
          const Text('No appointments awaiting verification.'),
        ...appointments.map(
          (a) => Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display(a['patient_name']),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(display(a['user_identifier'])),
                const SizedBox(height: 8),
                const StatusBadge('pending'),
                InfoLine(
                  Icons.local_hospital_outlined,
                  display(a['department_name']),
                ),
                InfoLine(
                  Icons.calendar_month,
                  '${a['appointment_date']}  ${a['appointment_time']}',
                ),
                InfoLine(
                  Icons.person_outline,
                  display(a['doctor_name'], 'Any available doctor'),
                ),
                InfoLine(Icons.notes, display(a['reason_for_visit'])),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: c.saving
                        ? null
                        : () async {
                            if (await confirm(
                                  context,
                                  'Verify Appointment',
                                  'Confirm the appointment for ${a['patient_name']} (${a['user_identifier']}) on ${a['appointment_date']} at ${a['appointment_time']}?',
                                ) &&
                                context.mounted) {
                              await perform(
                                context,
                                () => c.submit(
                                  '/appointments/${a['appointment_id']}/verify',
                                  {},
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verify Appointment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
