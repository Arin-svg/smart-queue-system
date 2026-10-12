import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'widgets/record_editor.dart';

class DepartmentsPage extends StatelessWidget {
  const DepartmentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    return ClinicPage(
      title: 'Department Management',
      children: [
        FilledButton.icon(
          onPressed: () => edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Department'),
        ),
        const SizedBox(height: 14),
        if (c.rows('departments').isEmpty)
          const EmptyState(
            'No departments',
            'Add a department to enable clinic services.',
          ),
        ...c
            .rows('departments')
            .map(
              (d) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoLine(Icons.apartment, '${d['department_name']}'),
                    Text('Code: ${display(d['department_code'], '—')}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        StatusBadge('${d['status']}'),
                        Text(
                          '${c.rows('rooms').where((r) => r['department_id'] == d['department_id']).length} rooms',
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => edit(context, d),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton(
                          onPressed: c.saving
                              ? null
                              : () async {
                                  if (await confirm(
                                        context,
                                        'Change Department Status',
                                        '${d['status'] == 'active' ? 'Disable' : 'Enable'} ${d['department_name']}?',
                                      ) &&
                                      context.mounted) {
                                    await perform(
                                      context,
                                      () => c.submit(
                                        '/admin/departments/${d['department_id']}',
                                        {
                                          ...d,
                                          'status': d['status'] == 'active'
                                              ? 'inactive'
                                              : 'active',
                                        },
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            d['status'] == 'active' ? 'Disable' : 'Enable',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> edit(BuildContext context, [Record? d]) => editRecord(
    context,
    title: d == null ? 'Add Department' : 'Edit Department',
    endpoint: '/admin/departments${d == null ? '' : '/${d['department_id']}'}',
    fields: [
      EditField(
        'department_name',
        'Department Name',
        initial: d?['department_name'],
      ),
      EditField(
        'department_code',
        'Department Code',
        initial: d?['department_code'],
      ),
      EditField(
        'description',
        'Description',
        required: false,
        initial: d?['description'],
      ),
      EditField(
        'status',
        'Status',
        options: const [('active', 'Active'), ('inactive', 'Inactive')],
        initial: d?['status'] ?? 'active',
      ),
    ],
  );
}
