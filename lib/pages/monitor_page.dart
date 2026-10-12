import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'registration_page.dart';

class StaffSummary extends StatelessWidget {
  const StaffSummary({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final q = c.rows('queues');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          display(c.profile['name'], ''),
          style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SummaryTiles([
          (
            'Waiting',
            '${q.where((r) => r['queue_status'] == 'waiting').length}',
            Colors.amber,
          ),
          (
            'Verified',
            '${q.where((r) => r['queue_status'] == 'verified').length}',
            Colors.blue,
          ),
          ('Active', '${c.activeQueues.length}', Colors.cyan),
          (
            'Appts',
            '${c.rows('appointments').where((a) => ['pending', 'confirmed'].contains(a['appointment_status'])).length}',
            Colors.teal,
          ),
        ]),
      ],
    );
  }
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key});
  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  String? department, status;
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final queues = c
        .rows('queues')
        .where(
          (q) =>
              (department == null ||
                  department!.isEmpty ||
                  '${q['department_id']}' == department) &&
              (status == null ||
                  status!.isEmpty ||
                  q['queue_status'] == status),
        )
        .toList();
    return ClinicPage(
      title: 'Staff',
      children: [
        const StaffSummary(),
        Row(
          children: [
            Expanded(
              child: ChoiceField(
                label: 'All Departments',
                optional: true,
                items: choices(
                  c.rows('departments'),
                  'department_id',
                  'department_name',
                ),
                value: department,
                onChanged: (v) => setState(() => department = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceField(
                label: 'All Status',
                optional: true,
                items: [
                  ...WorkspaceController.activeStatuses,
                  'completed',
                  'absent',
                  'cancelled',
                ].map((s) => (s, label(s))).toList(),
                value: status,
                onChanged: (v) => setState(() => status = v),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: OutlinedButton.icon(
            onPressed: () =>
                openClinicPage(context, const RegistrationPage(staff: true)),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Register Walk-in Patient'),
          ),
        ),
        if (queues.isEmpty)
          const EmptyState(
            'No queues found',
            'Try a different filter or register a walk-in patient.',
          ),
        ...queues.map(
          (q) => QueueCard(
            q,
            actions: [
              if (q['queue_status'] == 'skipped')
                TextButton(
                  onPressed: c.saving
                      ? null
                      : () => perform(
                          context,
                          () => c.submit('/queues/${q['queue_id']}', {
                            'action': 'requeue',
                          }),
                        ),
                  child: const Text('Requeue Patient'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
