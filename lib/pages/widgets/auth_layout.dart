import 'package:flutter/material.dart';
import '../../config/app_config.dart';

const authGreen = Color(0xFF00BD98);
const authTeal = Color(0xFF009B8F);
const authSurface = Color(0xFFF8F9FD);

/// Shared view components for the authentication screens.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authSurface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final minimumHeight =
              640.0 +
              (MediaQuery.textScalerOf(context).scale(160) - 160).clamp(0, 640);
          final height = constraints.maxHeight < minimumHeight
              ? minimumHeight
              : constraints.maxHeight;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Container(
                height: height,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF00C3A5), authGreen],
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 48,
                      child: SafeArea(
                        bottom: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _HealthMark(),
                                const SizedBox(height: 30),
                                Text(
                                  AppConfig.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 52,
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: authSurface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 24,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                child: child,
                              ),
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
    );
  }
}

class _HealthMark extends StatelessWidget {
  const _HealthMark();
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.favorite_border_rounded,
            size: 52,
            color: Color(0xFFB7F5DF),
          ),
        ),
        Positioned(
          top: -7,
          right: -7,
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF55D9B4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 18, color: authTeal),
          ),
        ),
      ],
    );
  }
}

InputDecoration authInputDecoration(String hint, {IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF7B838A), fontSize: 13),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 19, color: const Color(0xFF87928F)),
    filled: true,
    fillColor: authSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFDCE2E2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: authTeal, width: 2),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [authGreen, authTeal]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: authGreen.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
