import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'widgets/record_editor.dart';
import 'qr_code_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final summary = Record.from(c.data['summary'] as Map? ?? {});
    return ClinicPage(
      title: 'Admin',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            display(c.profile['name'], ''),
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ),
        SummaryTiles([
          ('Total Queues', '${summary['total'] ?? 0}', Colors.purple),
          ('Active Queues', '${summary['active'] ?? 0}', Colors.orange),
          ('Completed', '${summary['completed'] ?? 0}', Colors.teal),
        ]),
        for (final item in [
          (
            Icons.schedule,
            'Average Wait Time',
            '${summary['average_wait_minutes'] ?? '—'} min',
          ),
          (
            Icons.people_outline,
            'Total Users',
            '${summary['users'] ?? c.rows('users').length}',
          ),
          (
            Icons.apartment_outlined,
            'Active Departments',
            '${summary['active_departments'] ?? c.rows('departments').where((d) => d['status'] == 'active').length}',
          ),
        ])
          Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.$1,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                item.$2,
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              subtitle: Text(
                item.$3,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Queue Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Registration: ${(c.data['settings'] as Map?)?['registration_open'] == true || (c.data['settings'] as Map?)?['registration_open'] == 1 ? 'Open' : 'Closed'}',
              ),
              OutlinedButton(
                onPressed: () => settings(context, c),
                child: const Text('Configure Queue Settings'),
              ),
              OutlinedButton.icon(
                onPressed: () => openClinicPage(context, const QrCodePage()),
                icon: const Icon(Icons.qr_code),
                label: const Text('Manage Clinic QR Code'),
              ),
              OutlinedButton(
                onPressed: c.saving
                    ? null
                    : () async {
                        final s = Record.from(c.data['settings'] as Map? ?? {});
                        final open =
                            s['registration_open'] == true ||
                            s['registration_open'] == 1;
                        if (await confirm(
                              context,
                              open ? 'Close Registration' : 'Open Registration',
                              'Change walk-in registration availability?',
                            ) &&
                            context.mounted) {
                          await perform(
                            context,
                            () => c.submit('/admin/settings', {
                              ...s,
                              'registration_open': !open,
                            }),
                          );
                        }
                      },
                child: const Text('Open / Close Registration'),
              ),
            ],
          ),
        ),
        Panel(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('System Logs'),
            children: [
              if (c.rows('logs').isEmpty)
                const ListTile(title: Text('No system activity yet.')),
              ...c
                  .rows('logs')
                  .map(
                    (l) => ListTile(
                      title: Text(label(l['action'])),
                      subtitle: Text(
                        '${display(l['actor_name'], 'System')} · ${l['created_at']}\n${l['record_type']} #${l['record_id'] ?? ''}',
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> settings(BuildContext context, WorkspaceController c) async {
    final s = Record.from(c.data['settings'] as Map? ?? {});
    await editRecord(
      context,
      title: 'Queue Settings',
      endpoint: '/admin/settings',
      fields: [
        EditField(
          'average_minutes',
          'Default Consultation Minutes',
          number: true,
          initial: s['average_minutes'],
        ),
        EditField(
          'slot_minutes',
          'Appointment Slot Minutes',
          number: true,
          initial: s['slot_minutes'],
        ),
        EditField(
          'slot_capacity',
          'Patients per Slot',
          number: true,
          initial: s['slot_capacity'],
        ),
        EditField(
          'opening_time',
          'Opening Time (HH:mm)',
          initial: s['opening_time'],
        ),
        EditField(
          'closing_time',
          'Closing Time (HH:mm)',
          initial: s['closing_time'],
        ),
        EditField(
          'registration_open',
          'Registration',
          options: const [('1', 'Open'), ('0', 'Closed')],
          initial: s['registration_open'] == true || s['registration_open'] == 1
              ? '1'
              : '0',
        ),
      ],
    );
  }
}
