import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'widgets/record_editor.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String search = '';
  String? role;
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final rows = c
        .rows('users')
        .where(
          (u) =>
              (role == null || role!.isEmpty || '${u['role_id']}' == role) &&
              '${u['name']} ${u['email']} ${u['user_identifier']}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return ClinicPage(
      title: 'User Management',
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search users…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 14),
        ChoiceField(
          label: 'All Roles',
          optional: true,
          items: choices(c.rows('roles'), 'role_id', 'role_name'),
          value: role,
          onChanged: (v) => setState(() => role = v),
        ),
        FilledButton.icon(
          onPressed: () => edit(context, c),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Add User'),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const EmptyState(
            'No users found',
            'Try another search or add a new user.',
          ),
        ...rows.map(
          (u) => Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${u['name']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    StatusBadge('${u['role_name']}'),
                  ],
                ),
                InfoLine(Icons.email_outlined, '${u['email']}'),
                InfoLine(Icons.badge_outlined, '${u['user_identifier']}'),
                InfoLine(Icons.phone_outlined, display(u['phone_no'], '—')),
                const SizedBox(height: 10),
                StatusBadge('${u['status']}'),
                const Divider(height: 28),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => edit(context, c, u),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                    OutlinedButton(
                      onPressed: c.saving
                          ? null
                          : () async {
                              final action = u['status'] == 'active'
                                  ? 'Disable'
                                  : 'Enable';
                              if (await confirm(
                                    context,
                                    '$action User',
                                    '$action ${u['name']}?',
                                  ) &&
                                  context.mounted) {
                                await perform(
                                  context,
                                  () =>
                                      c.submit('/admin/users/${u['user_id']}', {
                                        ...u,
                                        'status': u['status'] == 'active'
                                            ? 'inactive'
                                            : 'active',
                                      }),
                                );
                              }
                            },
                      child: Text(
                        u['status'] == 'active' ? 'Disable' : 'Enable',
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

  Future<void> edit(BuildContext context, WorkspaceController c, [Record? u]) =>
      editRecord(
        context,
        title: u == null ? 'Add New User' : 'Edit User',
        endpoint: '/admin/users${u == null ? '' : '/${u['user_id']}'}',
        fields: [
          EditField('name', 'Full Name', initial: u?['name']),
          EditField('email', 'Email', initial: u?['email']),
          EditField(
            'role_id',
            'Role',
            options: choices(c.rows('roles'), 'role_id', 'role_name'),
            initial: u?['role_id'],
          ),
          EditField(
            'user_identifier',
            'Staff / Student ID',
            initial: u?['user_identifier'],
          ),
          EditField(
            'phone_no',
            'Phone',
            required: false,
            initial: u?['phone_no'],
          ),
          EditField(
            'password',
            u == null ? 'Password' : 'New Password (optional)',
            required: u == null,
            secret: true,
          ),
          EditField(
            'status',
            'Status',
            options: const [('active', 'Active'), ('inactive', 'Inactive')],
            initial: u?['status'] ?? 'active',
          ),
        ],
      );
}
