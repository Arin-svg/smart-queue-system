import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'config/api.dart';
import 'config/auth_config.dart';
import 'controller/auth_controller.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'pages/session_page.dart';
import 'pages/login_page.dart';
import 'pages/forgot_password.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

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
  void initState() {
    super.initState();
    _auth.restoreSession();
  }

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
        builder: (context, _) => _auth.restoring || _auth.restoreError != null
            ? Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _auth.restoring
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 20),
                              Text('Restoring your session…'),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 40),
                              const SizedBox(height: 16),
                              Text(
                                _auth.restoreError!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _auth.restoreSession,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                  ),
                ),
              )
            : _auth.user == null
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
