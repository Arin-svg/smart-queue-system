import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'monitor_page.dart';

class VerifyPage extends StatelessWidget {
  const VerifyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final queues = c.orderedQueues
        .where((q) => q['queue_status'] == 'waiting')
        .toList();
    return ClinicPage(
      title: 'Staff',
      children: [
        const StaffSummary(),
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text('Verify patients before assigning'),
        ),
        if (queues.isEmpty)
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
      ],
    );
  }
}
