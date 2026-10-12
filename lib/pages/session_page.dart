import 'package:flutter/material.dart';
import '../controller/auth_controller.dart';
import '../model/role.dart';
import '../services/api_service.dart';
import 'widgets/clinic_widgets.dart';
import 'queue_page.dart';
import 'appointment_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'monitor_page.dart';
import 'verify_page.dart';
import 'assign_page.dart';
import 'qr_code_page.dart';
import 'call_patient_page.dart';
import 'consultation_page.dart';
import 'dashboard_page.dart';
import 'users_page.dart';
import 'departments_page.dart';
import 'rooms_page.dart';
import 'reports_page.dart';
import 'registration_page.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key, required this.controller, required this.api});
  final AuthController controller;
  final ApiService api;
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with WidgetsBindingObserver {
  late final WorkspaceController workspace = WorkspaceController(widget.api);
  String? selected;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    workspace.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      workspace.refresh();
      workspace.resume();
    } else {
      workspace.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    workspace.dispose();
    super.dispose();
  }

  void navigate(String page) => setState(() => selected = page);
  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user!;
    final (color, role, destinations) = switch (user.role) {
      Role.patient => (
        const Color(0xFF00B98E),
        'Patient',
        <(String, IconData, Widget)>[
          ('Scan', Icons.qr_code_scanner, const RegistrationPage()),
          ('My Queue', Icons.format_list_numbered, const QueuePage()),
          ('Appts', Icons.calendar_month_outlined, const AppointmentPage()),
          ('Alerts', Icons.notifications_none, const NotificationPage()),
          ('Profile', Icons.account_circle_outlined, const ProfilePage()),
        ],
      ),
      Role.staff => (
        const Color(0xFF00ACCD),
        'Registration Staff',
        <(String, IconData, Widget)>[
          ('Monitor', Icons.desktop_windows_outlined, const MonitorPage()),
          ('Verify', Icons.verified_outlined, const VerifyPage()),
          ('Assign', Icons.person_add_alt, const AssignPage()),
          ('QR Code', Icons.qr_code, const QrCodePage()),
          ('Profile', Icons.account_circle_outlined, const ProfilePage()),
        ],
      ),
      Role.doctor => (
        const Color(0xFFFF9300),
        'Doctor',
        <(String, IconData, Widget)>[
          ('Call', Icons.phone_in_talk_outlined, const CallPatientPage()),
          (
            'Consult',
            Icons.medical_services_outlined,
            const ConsultationPage(),
          ),
          ('Profile', Icons.account_circle_outlined, const ProfilePage()),
        ],
      ),
      Role.administrator => (
        const Color(0xFF9345FF),
        'Admin',
        <(String, IconData, Widget)>[
          ('Home', Icons.home_outlined, const DashboardPage()),
          ('Users', Icons.people_outline, const UsersPage()),
          ('Depts', Icons.apartment_outlined, const DepartmentsPage()),
          ('Rooms', Icons.meeting_room_outlined, const RoomsPage()),
          ('Reports', Icons.bar_chart, const ReportsPage()),
          ('Profile', Icons.account_circle_outlined, const ProfilePage()),
        ],
      ),
    };
    final index = destinations.indexWhere((d) => d.$1 == selected);
    final current = index < 0 ? 0 : index;
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: color, primary: color),
      scaffoldBackgroundColor: const Color(0xFFF7F7FC),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFD),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE4E6ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE4E6ED)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: ClinicScope(
        controller: workspace,
        navigate: navigate,
        role: user.role.name,
        child: Builder(
          builder: (context) {
            final c = ClinicScope.of(context).controller;
            return Scaffold(
              appBar: AppBar(
                backgroundColor: color,
                foregroundColor: Colors.white,
                toolbarHeight: 76,
                title: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0x30FFFFFF),
                      child: Icon(Icons.favorite_border, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'SQS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                actions: [
                  PopupMenuButton<String>(
                    tooltip: 'Account menu',
                    icon: CircleAvatar(
                      backgroundColor: const Color(0xFFDDE8E7),
                      child: Text(
                        user.name.isEmpty ? '?' : user.name[0],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    onSelected: (value) async {
                      if (value == 'profile') {
                        navigate('Profile');
                        return;
                      }
                      await widget.controller.logout();
                      if (context.mounted && widget.controller.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(widget.controller.error!)),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(user.email),
                            Text(display(c.profile['phone_no'], role)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'profile',
                        child: ListTile(
                          leading: Icon(Icons.account_circle_outlined),
                          title: Text('My Profile'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        enabled: !widget.controller.isLoading,
                        child: const ListTile(
                          leading: Icon(Icons.logout, color: Colors.red),
                          title: Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: Column(
                children: [
                  if (c.loading) const LinearProgressIndicator(minHeight: 2),
                  if (c.error != null)
                    Material(
                      color: const Color(0xFFFFEDEA),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(c.error!)),
                            TextButton(
                              onPressed: c.refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: c.data.isEmpty && c.loading
                            ? const Center(child: CircularProgressIndicator())
                            : destinations[current].$3,
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFDDE0E6))),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 6,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == current,
                            button: true,
                            child: InkWell(
                              onTap: () => navigate(destinations[i].$1),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: i == current
                                      ? color.withValues(alpha: .09)
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      destinations[i].$2,
                                      size: 23,
                                      color: i == current
                                          ? color
                                          : const Color(0xFFA0A8B7),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      destinations[i].$1,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: i == current
                                            ? color
                                            : const Color(0xFF8B94A5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
