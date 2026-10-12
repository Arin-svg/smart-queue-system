import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'config/api.dart';
import 'config/auth_config.dart';
import 'controller/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'pages/session_page.dart';
import 'pages/login_page.dart';
import 'pages/forgot_password.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authService, this.apiService});
  final AuthService? authService;
  final ApiService? apiService;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final HttpApiService _http = HttpApiService(baseUrl: ApiConfig.baseUrl);
  late final ApiService _api = widget.apiService ?? _http;
  late final AuthController _auth = AuthController(
    widget.authService ?? LaravelAuthService(_http),
  );
  @override
  void dispose() {
    _auth.dispose();
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConfig.name,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    ),
    initialRoute: AuthConfig.loginRoute,
    routes: {
      AuthConfig.loginRoute: (_) => ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => _auth.user == null
            ? LoginPage(controller: _auth)
            : SessionPage(
                key: ValueKey(_auth.user!.id),
                controller: _auth,
                api: _api,
              ),
      ),
      AuthConfig.forgotPasswordRoute: (_) => ForgotPassword(controller: _auth),
    },
  );
}
