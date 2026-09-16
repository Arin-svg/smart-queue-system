import 'package:flutter/material.dart';
import '../config/auth_config.dart';
import '../controller/auth_controller.dart';
import 'widgets/auth_layout.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key, required this.controller});
  final AuthController controller;
  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _email = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.controller.requestPasswordReset(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7F8EB),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    color: authGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                IconButton(
                  tooltip: 'Back to login',
                  icon: const Icon(Icons.close, size: 19),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(
                        context,
                        AuthConfig.loginRoute,
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter your registered email address and we'll send you password reset instructions.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF717A80),
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Email',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 7),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration:
                  authInputDecoration(
                    'name@pku.id',
                    icon: Icons.mail_outline_rounded,
                  ).copyWith(
                    labelText: 'Email',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
            ),
            const SizedBox(height: 14),
            if (widget.controller.resetMessage != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  widget.controller.resetMessage!,
                  style: TextStyle(
                    color: widget.controller.resetSucceeded
                        ? authTeal
                        : Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            AuthButton(
              label: widget.controller.isResetting
                  ? 'Sending...'
                  : 'Send Reset Instructions',
              onPressed: widget.controller.isResetting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
