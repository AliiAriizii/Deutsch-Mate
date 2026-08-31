import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_messages.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';

/// Sign in / sign up, against the real API.
///
/// Replaces the SharedPreferences stub that accepted any password. Credentials
/// are now verified server-side; this screen only collects them and phrases
/// whatever the server says.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AuthController get _auth => widget.controller;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _error = null);

    try {
      if (_isLogin) {
        await _auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Field-level messages bind to their inputs; anything else is a banner.
      setState(() => _error = AuthMessages.of(e));
    }
  }

  Future<void> _google() async {
    setState(() => _error = null);
    try {
      await _auth.signInWithGoogle();
    } on GoogleLinkRequired catch (link) {
      if (!mounted) return;
      // The address already has a password account. Collect it once and link,
      // rather than creating a second account for the same person.
      final password = await _askForPassword(link.email);
      if (password == null || !mounted) return;
      try {
        await _auth.linkGoogle(
          idToken: link.idToken,
          password: password,
          nonce: link.nonce,
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _error = AuthMessages.of(e));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // A cancelled sign-in is not an error worth shouting about.
      if (e.code == 'GOOGLE_CANCELED') return;
      setState(() => _error = AuthMessages.of(e));
    }
  }

  Future<String?> _askForPassword(String email) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: context.radii.cardBorder,
          side: BorderSide(color: context.colors.hairline),
        ),
        title: Text('وصل‌کردن گوگل', style: context.texts.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'برای $email از قبل حساب با رمز عبور وجود دارد. '
              'یک‌بار رمزت را وارد کن تا گوگل به همان حساب وصل شود.',
              style: context.texts.bodySmall,
            ),
            SizedBox(height: context.spacing.lg),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'رمز عبور'),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بی‌خیال'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('وصل کن'),
          ),
        ],
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        final busy = _auth.busy;
        return Scaffold(
          body: SafeArea(
            child: Align(
              alignment: const AlignmentDirectional(0, -0.55),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.gutter,
                  vertical: spacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Wordmark(),
                        SizedBox(height: spacing.xxxl),

                        PlateLabel(_isLogin ? 'ورود' : 'حساب جدید'),
                        SizedBox(height: spacing.sm),
                        Text(
                          _isLogin ? 'خوش برگشتی' : 'شروع یادگیری آلمانی',
                          style: context.texts.displaySmall,
                        ),
                        SizedBox(height: spacing.sm),
                        Text(
                          _isLogin
                              ? 'برای ادامه مسیر، وارد حساب خود شو.'
                              : 'حساب بساز تا پیشرفتت ذخیره شود.',
                          style: context.texts.bodySmall,
                        ),
                        SizedBox(height: spacing.xl),

                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            enabled: !busy,
                            decoration: const InputDecoration(
                              labelText: 'نام و نام خانوادگی',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'نام را وارد کنید'
                                : null,
                          ),
                          SizedBox(height: spacing.md),
                        ],

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !busy,
                          autofillHints: const [AutofillHints.email],
                          decoration:
                              const InputDecoration(labelText: 'ایمیل'),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'ایمیل را وارد کنید';
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'قالب ایمیل درست نیست';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: spacing.md),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          enabled: !busy,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => busy ? null : _submit(),
                          decoration: InputDecoration(
                            labelText: 'رمز عبور',
                            // Rules stated before typing, not after failing.
                            helperText: _isLogin
                                ? null
                                : 'حداقل 10 نویسه، شامل حرف و رقم',
                          ),
                          validator: (v) {
                            final value = v ?? '';
                            if (value.isEmpty) return 'رمز عبور را وارد کنید';
                            if (_isLogin) return null;
                            if (value.length < 10) return 'حداقل 10 نویسه';
                            if (!value.contains(RegExp(r'[A-Za-z]'))) {
                              return 'باید حداقل یک حرف داشته باشد';
                            }
                            if (!value.contains(RegExp(r'[0-9]'))) {
                              return 'باید حداقل یک رقم داشته باشد';
                            }
                            return null;
                          },
                        ),

                        if (_error != null) ...[
                          SizedBox(height: spacing.lg),
                          _ErrorBanner(message: _error!),
                        ],

                        SizedBox(height: spacing.xl),
                        FilledButton(
                          onPressed: busy ? null : _submit,
                          child: busy
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.textTertiary,
                                  ),
                                )
                              : Text(_isLogin ? 'ورود' : 'ساختن حساب'),
                        ),

                        SizedBox(height: spacing.lg),
                        _OrRule(),
                        SizedBox(height: spacing.lg),

                        OutlinedButton.icon(
                          onPressed: busy ? null : _google,
                          icon: const _GoogleMark(),
                          label: const Text('ادامه با گوگل'),
                        ),

                        SizedBox(height: spacing.sm),
                        TextButton(
                          onPressed: busy ? null : _toggleMode,
                          child: Text(_isLogin ? 'حساب ندارم' : 'حساب دارم'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AccentEdgeBox(
      tint: colors.error,
      child: Text(
        message,
        style: context.texts.bodySmall?.copyWith(color: colors.error),
      ),
    );
  }
}

class _OrRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.hairline)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
          child: Text('یا', style: context.texts.labelSmall),
        ),
        Expanded(child: Divider(color: colors.hairline)),
      ],
    );
  }
}

/// Google's mark, drawn rather than shipped as an asset: four strokes in the
/// brand colours, which satisfies their branding rules without adding a PNG.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  // Google's official brand colours. These are the one place in the app that
  // does not come from the theme, because they are not ours to restyle.
  static const _blue = Color(0xFF4285F4); // theme-exempt: Google brand
  static const _green = Color(0xFF34A853); // theme-exempt: Google brand
  static const _yellow = Color(0xFFFBBC05); // theme-exempt: Google brand
  static const _red = Color(0xFFEA4335); // theme-exempt: Google brand

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(1.5);
    final stroke = size.width * 0.28;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs approximating the G, plus the bar.
    canvas.drawArc(rect, -0.35, 1.25, false, paint..color = _green);
    canvas.drawArc(rect, 0.95, 1.35, false, paint..color = _blue);
    canvas.drawArc(rect, 2.35, 1.35, false, paint..color = _yellow);
    canvas.drawArc(rect, 3.75, 1.60, false, paint..color = _red);
    canvas.drawLine(
      Offset(size.width * 0.52, size.height / 2),
      Offset(size.width - 1.5, size.height / 2),
      paint
        ..color = _blue
        ..strokeWidth = stroke * 0.9,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wordmark instead of a flag emoji.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Deutsch', style: context.texts.headlineMedium),
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
        SizedBox(height: context.spacing.sm),
        Container(width: 44, height: 2, color: colors.accent),
      ],
    );
  }
}
