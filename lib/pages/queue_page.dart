import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});
  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  bool history = false;
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
                    onPressed: () => setState(() => history = !history),
                    icon: Icons.history,
                    label: history ? 'My Queue' : 'History',
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
      ],
    );
  }
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
