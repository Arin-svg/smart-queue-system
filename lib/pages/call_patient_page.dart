import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';

class DoctorSummary extends StatelessWidget {
  const DoctorSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final rows = ClinicScope.of(context).controller.rows('queues');
    return SummaryTiles([
      for (final item in [
        ('assigned', 'Assigned', Colors.cyan),
        ('called', 'Called', Colors.teal),
        ('in_consultation', 'In Consult', Colors.orange),
        ('completed', 'Done', Colors.green),
      ])
        (
          item.$2,
          '${rows.where((q) => q['queue_status'] == item.$1).length}',
          item.$3,
        ),
    ]);
  }
}

class CallPatientPage extends StatelessWidget {
  const CallPatientPage({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = ClinicScope.of(context), c = scope.controller;
    final waiting = c.orderedQueues
        .where((q) => q['queue_status'] == 'assigned')
        .toList();
    final busy = c
        .rows('queues')
        .any((q) => ['called', 'in_consultation'].contains(q['queue_status']));
    return ClinicPage(
      title: 'Call Next',
      children: [
        const DoctorSummary(),
        if (busy)
          Panel(
            tint: const Color(0xFFFFF4E3),
            child: Column(
              children: [
                const Text('A patient is currently called or in consultation.'),
                TextButton(
                  onPressed: () => scope.navigate('Consult'),
                  child: const Text('Open Consultation'),
                ),
              ],
            ),
          ),
        if (waiting.isEmpty)
          const EmptyState(
            'No patients waiting',
            'Newly assigned patients will appear here.',
          ),
        if (waiting.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'NEXT UP',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          QueueCard(
            waiting.first,
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy || c.saving
                      ? null
                      : () async {
                          final result = await perform(
                            context,
                            () => c.submit(
                              '/queues/${waiting.first['queue_id']}',
                              {'action': 'call'},
                            ),
                          );
                          if (result != null) scope.navigate('Consult');
                        },
                  icon: const Icon(Icons.phone_in_talk_outlined),
                  label: const Text('Call Patient'),
                ),
              ),
            ],
          ),
          Text(
            'Waiting  ${waiting.length}',
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),
          ...waiting
              .skip(1)
              .map(
                (q) => Panel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      '${q['queue_number']}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    title: Text('${q['patient_name']}'),
                    subtitle: Text('${q['department_name']}'),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
