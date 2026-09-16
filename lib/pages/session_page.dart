import 'package:flutter/material.dart';
import '../controller/auth_controller.dart';
import '../model/role.dart';

/// Landing page while the role-specific feature screens are built.
class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.controller});
  final AuthController controller;
  @override
  Widget build(BuildContext context) {
    final user = controller.user!;
    final role = switch (user.role) {
      Role.patient => 'Patient',
      Role.staff => 'Registration Staff',
      Role.doctor => 'Doctor',
      Role.administrator => 'Administrator',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Queue System')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 64,
                color: Colors.teal,
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${user.name}',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Chip(label: Text(role)),
              Text(user.email),
              const SizedBox(height: 20),
              const Text(
                'You are signed in. Your dashboard is coming next.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (controller.error != null)
                Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                onPressed: controller.isLoading ? null : controller.logout,
                child: Text(
                  controller.isLoading ? 'Signing out...' : 'Sign out',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
