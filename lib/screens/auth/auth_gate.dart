import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../main_container_screen.dart';
import '../../theme/app_tokens.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import 'verify_email_screen.dart';

/// Decides which screen the app opens on.
///
/// The whole reason this exists is the "no flash of the wrong screen" rule:
/// while the stored session is being refreshed the stage is `restoring` and
/// this shows a quiet splash. Routing to the auth screen first and then
/// replacing it once the refresh lands is exactly what the rule forbids.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => switch (controller.stage) {
        AuthStage.restoring => const _RestoringSplash(),
        AuthStage.signedOut => AuthScreen(controller: controller),
        AuthStage.awaitingEmailVerification =>
          VerifyEmailScreen(controller: controller),
        AuthStage.onboardingRequired => OnboardingScreen(controller: controller),
        AuthStage.signedIn => const MainContainerScreen(),
      },
    );
  }
}

/// Deliberately almost empty: it is on screen for a few hundred milliseconds,
/// and a spinner over a wordmark reads as intentional where a half-built
/// dashboard reads as a bug.
class _RestoringSplash extends StatelessWidget {
  const _RestoringSplash();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Deutsch',
                    style: context.texts.headlineMedium,
                  ),
                  TextSpan(
                    text: 'Mate',
                    style: context.texts.headlineMedium?.copyWith(
                      color: colors.accentSoft,
                    ),
                  ),
                ],
              ),
              textDirection: TextDirection.ltr,
            ),
            SizedBox(height: context.spacing.xl),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
