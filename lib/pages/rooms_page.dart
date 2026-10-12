import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'widgets/record_editor.dart';

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    return ClinicPage(
      title: 'Room Management',
      children: [
        FilledButton.icon(
          onPressed: () => edit(context, c),
          icon: const Icon(Icons.add),
          label: const Text('Add Room'),
        ),
        const SizedBox(height: 14),
        if (c.rows('rooms').isEmpty)
          const EmptyState(
            'No rooms',
            'Add consultation rooms and assign doctors.',
          ),
        ...c
            .rows('rooms')
            .map(
              (r) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['room_name']}  ${display(r['room_number'], '')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    InfoLine(
                      Icons.apartment,
                      c
                              .rows('departments')
                              .where(
                                (d) => d['department_id'] == r['department_id'],
                              )
                              .map((d) => '${d['department_name']}')
                              .firstOrNull ??
                          '—',
                    ),
                    InfoLine(
                      Icons.medical_services_outlined,
                      c
                              .rows('doctors')
                              .where((d) => d['user_id'] == r['doctor_id'])
                              .map((d) => '${d['name']}')
                              .firstOrNull ??
                          'Not assigned',
                    ),
                    const SizedBox(height: 10),
                    StatusBadge('${r['status']}'),
                    const Divider(height: 28),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => edit(context, c, r),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton(
                          onPressed: c.saving
                              ? null
                              : () async {
                                  if (await confirm(
                                        context,
                                        'Change Room Status',
                                        '${r['status'] == 'available' ? 'Disable' : 'Enable'} ${r['room_name']}?',
                                      ) &&
                                      context.mounted) {
                                    await perform(
                                      context,
                                      () => c.submit(
                                        '/admin/rooms/${r['room_id']}',
                                        {
                                          ...r,
                                          'status': r['status'] == 'available'
                                              ? 'inactive'
                                              : 'available',
                                        },
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            r['status'] == 'available' ? 'Disable' : 'Enable',
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

  Future<void> edit(BuildContext context, WorkspaceController c, [Record? r]) =>
      editRecord(
        context,
        title: r == null ? 'Add Room' : 'Edit Room',
        endpoint: '/admin/rooms${r == null ? '' : '/${r['room_id']}'}',
        fields: [
          EditField('room_name', 'Room Name', initial: r?['room_name']),
          EditField(
            'room_number',
            'Room Number',
            required: false,
            initial: r?['room_number'],
          ),
          EditField(
            'department_id',
            'Department',
            options: choices(
              c
                  .rows('departments')
                  .where((d) => d['status'] == 'active')
                  .toList(),
              'department_id',
              'department_name',
            ),
            initial: r?['department_id'],
          ),
          EditField(
            'doctor_id',
            'Assigned Doctor',
            required: false,
            options: choices(c.rows('doctors'), 'user_id', 'name'),
            initial: r?['doctor_id'],
          ),
          EditField(
            'status',
            'Status',
            options: const [
              ('available', 'Available'),
              ('unavailable', 'Unavailable'),
              ('inactive', 'Inactive'),
            ],
            initial: r?['status'] ?? 'available',
          ),
        ],
      );
}
