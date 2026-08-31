import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';

/// Shown when the server withheld tokens pending email confirmation.
///
/// There is nothing to persist in this state - no tokens were issued - so
/// there is no half-authenticated session to leak.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final email = controller.pendingEmail ?? '';

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: const AlignmentDirectional(0, -0.4),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.gutter,
              vertical: spacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PlateLabel('تأیید ایمیل'),
                  SizedBox(height: spacing.sm),
                  Text('ایمیلت را تأیید کن', style: context.texts.displaySmall),
                  SizedBox(height: spacing.md),
                  Text(
                    'لینک تأیید به این نشانی فرستاده شد. بازش کن تا حساب فعال شود.',
                    style: context.texts.bodyMedium,
                  ),
                  SizedBox(height: spacing.md),
                  AppCard(
                    background: context.colors.surface,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        email,
                        style: AppTypography.monoStyle(
                          color: context.colors.textPrimary,
                          size: 15,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  OutlinedButton(
                    onPressed: () => controller.signOut(),
                    child: const Text('با حساب دیگری وارد شو'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
