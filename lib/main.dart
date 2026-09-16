import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'config/auth_config.dart';
import 'controller/auth_controller.dart';
import 'services/auth_service.dart';
import 'pages/login_page.dart';
import 'pages/forgot_password.dart';
import 'pages/notification_page.dart';
import 'pages/qr_code_page.dart';
import 'pages/queue_page.dart';
import 'pages/appointment_page.dart';
import 'pages/assign_page.dart';
import 'pages/reports_page.dart';
import 'pages/monitor_page.dart';
import 'pages/verify_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/call_patient_page.dart';
import 'pages/consultation_page.dart';
import 'pages/rooms_page.dart';
import 'pages/users_page.dart';
import 'pages/departments_page.dart';
import 'pages/profile_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthController _auth = AuthController(UnconfiguredAuthService());

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      initialRoute: AuthConfig.loginRoute,
      routes: {
        AuthConfig.loginRoute: (_) => LoginPage(controller: _auth),
        AuthConfig.forgotPasswordRoute: (_) =>
            ForgotPassword(controller: _auth),
        '/notification': (_) => const NotificationPage(),
        '/qr-code': (_) => const QrCodePage(),
        '/queue': (_) => const QueuePage(),
        '/appointment': (_) => const AppointmentPage(),
        '/assign': (_) => const AssignPage(),
        '/reports': (_) => const ReportsPage(),
        '/monitor': (_) => const MonitorPage(),
        '/verify': (_) => const VerifyPage(),
        '/dashboard': (_) => const DashboardPage(),
        '/call-patient': (_) => const CallPatientPage(),
        '/consultation': (_) => const ConsultationPage(),
        '/rooms': (_) => const RoomsPage(),
        '/users': (_) => const UsersPage(),
        '/departments': (_) => const DepartmentsPage(),
        '/profile': (_) => const ProfilePage(),
      },
    );
  }
}
