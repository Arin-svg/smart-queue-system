import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = ClinicScope.of(context);
    final c = scope.controller;
    final user = c.profile;
    return ClinicPage(
      title: 'My Profile',
      children: [
        Panel(
          tint: const Color(0xFFEAFAF6),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFCBF6E8),
                child: Text(display(user['name'], '?')[0]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display(user['name'], ''),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(display(user['email'], '')),
                    const SizedBox(height: 5),
                    StatusBadge(scope.role),
                  ],
                ),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROFILE INFORMATION',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 16),
              for (final field in [
                ('Full Name', 'name'),
                ('Email', 'email'),
                ('Phone Number', 'phone_no'),
                ('Staff / Student ID', 'user_identifier'),
              ]) ...[
                Text(field.$1, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 7),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(display(user[field.$2], '—'))),
                      if (field.$2 == 'phone_no' && scope.role == 'patient')
                        IconButton(
                          tooltip: 'Edit phone number',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => editPhone(context, c),
                        )
                      else
                        const Text(
                          'Read-only',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Panel(
          child: Row(
            children: [
              const Icon(Icons.key_outlined, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Change Password')),
              OutlinedButton(
                onPressed: () => changePassword(context, c),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> editPhone(BuildContext context, WorkspaceController c) async {
    final phone = TextEditingController(
      text: display(c.profile['phone_no'], ''),
    );
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Update Phone Number'),
        content: TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          maxLength: 20,
          decoration: const InputDecoration(labelText: 'Phone Number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final result = await perform(
                context,
                () => c.submit('/profile', {'phone_no': phone.text.trim()}),
              );
              if (result != null && dialog.mounted) Navigator.pop(dialog);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    phone.dispose();
  }

  Future<void> changePassword(
    BuildContext context,
    WorkspaceController c,
  ) async {
    final current = TextEditingController(),
        password = TextEditingController(),
        confirmation = TextEditingController();
    final form = GlobalKey<FormState>();
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: current,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter current password'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                    ),
                    validator: (v) =>
                        v != password.text ? 'Passwords do not match' : null,
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
                        () => c.submit('/profile/password', {
                          'current_password': current.text,
                          'password': password.text,
                          'password_confirmation': confirmation.text,
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
              child: Text(saving ? 'Saving…' : 'Update Password'),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    password.dispose();
    confirmation.dispose();
  }
}
