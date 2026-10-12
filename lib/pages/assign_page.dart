import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'monitor_page.dart';
import 'widgets/prediction_panels.dart';

class AssignPage extends StatelessWidget {
  const AssignPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final queues = c.orderedQueues
        .where((q) => ['verified', 'assigned'].contains(q['queue_status']))
        .toList();
    return ClinicPage(
      title: 'Staff',
      children: [
        const StaffSummary(),
        PredictionPanels(queues),
        if (queues.isEmpty)
          const EmptyState(
            'No patients to assign',
            'Verify waiting patients first.',
          ),
        ...queues.map(
          (q) => QueueCard(
            q,
            actions: [
              FilledButton.icon(
                onPressed: c.saving ? null : () => assign(context, c, q),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  q['queue_status'] == 'assigned'
                      ? 'Reassign'
                      : 'Assign to Doctor',
                ),
              ),
              OutlinedButton(
                onPressed: c.saving ? null : () => priority(context, c, q),
                child: Text(
                  'Priority: ${['Normal', 'Medium', 'High'][(q['priority'] as int? ?? 0).clamp(0, 2)]}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> assign(
    BuildContext context,
    WorkspaceController c,
    Record q,
  ) async {
    String? doctor, room;
    final rooms = c
        .rows('rooms')
        .where(
          (r) =>
              r['status'] == 'available' &&
              r['department_id'] == q['department_id'] &&
              r['doctor_id'] != null,
        )
        .toList();
    final doctors = c
        .rows('doctors')
        .where((d) => rooms.any((r) => r['doctor_id'] == d['user_id']))
        .toList();
    final form = GlobalKey<FormState>();
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Assign Patient to Doctor'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${q['patient_name']} (Queue #${q['queue_number']})'),
                  const SizedBox(height: 20),
                  if (doctors.isEmpty)
                    const Text(
                      'No available doctor and room in this department. Ask the administrator to configure a room assignment.',
                    ),
                  ChoiceField(
                    label: 'Doctor',
                    items: choices(doctors, 'user_id', 'name'),
                    value: doctor,
                    onChanged: (v) => setState(() {
                      doctor = v;
                      room = null;
                    }),
                  ),
                  ChoiceField(
                    label: 'Room',
                    items: choices(
                      rooms
                          .where((r) => '${r['doctor_id']}' == doctor)
                          .toList(),
                      'room_id',
                      'room_name',
                    ),
                    value: room,
                    onChanged: (v) => setState(() => room = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => saving = true);
                      final result = await perform(
                        context,
                        () => c.submit('/queues/${q['queue_id']}', {
                          'action': 'assign',
                          'doctor_id': int.parse(doctor!),
                          'room_id': int.parse(room!),
                        }),
                        success:
                            'Queue ${q['queue_number']} assigned successfully.',
                      );
                      if (dialog.mounted) {
                        if (result != null) {
                          Navigator.pop(dialog);
                        } else {
                          setState(() => saving = false);
                        }
                      }
                    },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> priority(
    BuildContext context,
    WorkspaceController c,
    Record q,
  ) async {
    String? level = '${q['priority'] ?? 0}';
    final note = TextEditingController();
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Approve Queue Priority'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChoiceField(
                label: 'Priority',
                items: const [('0', 'Normal'), ('1', 'Medium'), ('2', 'High')],
                value: level,
                onChanged: (v) => setState(() => level = v),
              ),
              TextField(
                controller: note,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Reason for staff decision',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (note.text.trim().isEmpty) return;
                      setState(() => saving = true);
                      final result = await perform(
                        context,
                        () => c.submit('/queues/${q['queue_id']}', {
                          'action': 'priority',
                          'priority': int.parse(level!),
                          'priority_note': note.text.trim(),
                        }),
                      );
                      if (dialog.mounted) {
                        if (result != null) {
                          Navigator.pop(dialog);
                        } else {
                          setState(() => saving = false);
                        }
                      }
                    },
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
  }
}
