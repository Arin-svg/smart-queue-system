import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key, this.initialHistory = false});
  final bool initialHistory;
  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  late bool history = widget.initialHistory;
  @override
  Widget build(BuildContext context) {
    final scope = ClinicScope.of(context);
    final c = scope.controller;
    final queues = history
        ? c
              .rows('queues')
              .where(
                (q) => !WorkspaceController.activeStatuses.contains(
                  q['queue_status'],
                ),
              )
              .toList()
        : c.activeQueues;
    return ClinicPage(
      title: history ? 'Queue History' : 'My Queue',
      action: TextButton(
        onPressed: () => setState(() => history = !history),
        child: Text(history ? 'Active queue' : 'History'),
      ),
      children: [
        if (queues.isEmpty)
          EmptyState(
            history ? 'No past visits' : 'No active queue',
            history
                ? 'Your completed visits will appear here.'
                : 'Scan the clinic QR code to get your queue number.',
          ),
        ...queues.map(
          (q) => Column(
            children: [
              QueueCard(q),
              if (!history) ...[
                SummaryTiles([
                  (
                    'PREDICTED WAIT',
                    '~${q['estimated_waiting_time'] ?? '—'} min',
                    Colors.cyan,
                  ),
                  ('WAITING SINCE', elapsed(q['registered_at']), Colors.orange),
                ]),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${q['people_ahead'] ?? '—'} ${q['people_ahead'] == 1 ? 'patient' : 'patients'} ahead',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: switch (q['queue_status']) {
                          'waiting' => .15,
                          'verified' => .4,
                          'assigned' => .65,
                          'called' => .85,
                          'in_consultation' => 1,
                          _ => .15,
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(label(q['queue_status'])),
                      const SizedBox(height: 6),
                      Text(
                        '${q['estimate_method']}'.startsWith('AI:')
                            ? 'AI estimate based on recent clinic visits'
                            : 'Estimate based on clinic averages',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if ([
                  'waiting',
                  'verified',
                  'assigned',
                  'skipped',
                ].contains(q['queue_status']))
                  TextButton(
                    onPressed: c.saving
                        ? null
                        : () async {
                            if (await confirm(
                                  context,
                                  'Cancel queue?',
                                  'You will lose your current queue position.',
                                ) &&
                                context.mounted) {
                              await perform(
                                context,
                                () => c.submit('/queues/${q['queue_id']}', {
                                  'action': 'cancel',
                                }),
                              );
                            }
                          },
                    child: const Text('Cancel Queue'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
