import 'package:flutter/material.dart';
import '../config/auth_config.dart';
import '../controller/auth_controller.dart';
import 'widgets/auth_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final AuthController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userId = TextEditingController();
  final _password = TextEditingController();

  void _login() {
    FocusScope.of(context).unfocus();
    widget.controller.login(_userId.text, _password.text);
  }

  @override
  void dispose() {
    _userId.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) => AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'User ID',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _userId,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration:
                    authInputDecoration(
                      'e.g. CB20001, DOC001',
                      icon: Icons.person_outline_rounded,
                    ).copyWith(
                      labelText: 'User ID',
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.controller.clearResetFeedback();
                      Navigator.pushNamed(
                        context,
                        AuthConfig.forgotPasswordRoute,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: authTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: authInputDecoration('Enter your password').copyWith(
                  labelText: 'Password',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
              ),
              const SizedBox(height: 14),
              if (widget.controller.error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.controller.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AuthButton(
                label: widget.controller.isLoading ? 'Logging in...' : 'Log in',
                onPressed: widget.controller.isLoading ? null : _login,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
