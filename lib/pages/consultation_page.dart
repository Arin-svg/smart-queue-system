import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'call_patient_page.dart';

class ConsultationPage extends StatelessWidget {
  const ConsultationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final current = c
        .rows('queues')
        .where((q) => ['called', 'in_consultation'].contains(q['queue_status']))
        .toList();
    return ClinicPage(
      title: 'Consultation',
      children: [
        const DoctorSummary(),
        if (current.isEmpty)
          const EmptyState(
            'No current consultation',
            'Call the next patient to begin.',
          ),
        ...current.map(
          (q) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  q['queue_status'] == 'called'
                      ? 'PATIENT CALLED'
                      : 'NOW CONSULTING',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              QueueCard(
                q,
                actions: [
                  if (q['queue_status'] == 'called')
                    FilledButton.icon(
                      onPressed: c.saving
                          ? null
                          : () => perform(
                              context,
                              () => c.submit('/queues/${q['queue_id']}', {
                                'action': 'start',
                              }),
                            ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Consultation'),
                    ),
                  if (q['queue_status'] == 'in_consultation')
                    FilledButton.icon(
                      onPressed: c.saving
                          ? null
                          : () => change(
                              context,
                              c,
                              q,
                              'complete',
                              'Complete Consultation',
                            ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete'),
                    ),
                  if (q['queue_status'] == 'called') ...[
                    OutlinedButton(
                      onPressed: c.saving
                          ? null
                          : () => change(context, c, q, 'skip', 'Skip Patient'),
                      child: const Text('Skip'),
                    ),
                    OutlinedButton(
                      onPressed: c.saving
                          ? null
                          : () => change(
                              context,
                              c,
                              q,
                              'absent',
                              'Mark as Absent',
                            ),
                      child: const Text('Mark Absent'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> change(
    BuildContext context,
    WorkspaceController c,
    Record q,
    String action,
    String title,
  ) async {
    if (await confirm(
          context,
          title,
          '$title for ${q['patient_name']} (${q['queue_number']})?',
        ) &&
        context.mounted) {
      await perform(
        context,
        () => c.submit('/queues/${q['queue_id']}', {'action': action}),
      );
    }
  }
}
