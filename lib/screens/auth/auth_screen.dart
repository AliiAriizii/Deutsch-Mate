import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main_container_screen.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primitives.dart';

/// Sign in / sign up.
///
/// Visual pass only. The credential handling here is still the local
/// SharedPreferences stand-in and does not verify a password - that is
/// replaced wholesale when the client is wired to the API.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _busy = false;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveUserToJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('users_data');
      final users = (existing == null || existing.isEmpty)
          ? <dynamic>[]
          : jsonDecode(existing) as List<dynamic>;

      users.add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
      });

      await prefs.setString('users_data', jsonEncode(users));
    } catch (e) {
      // Only the failure type, never the payload: this map holds credentials.
      debugPrint('Failed to persist local user record: ${e.runtimeType}');
    }
  }

  Future<void> _submit() async {
    // Guards the double tap: the button also disables, but the flag is what
    // makes the handler itself idempotent.
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    if (!_isLogin) await _saveUserToJson();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainContainerScreen()),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      // Reset validation state so errors from the other mode do not linger.
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Scaffold(
      body: SafeArea(
        child: Align(
          // Anchored high rather than vertically centred. Centring left a third
          // of the screen empty above the wordmark, which reads as unfinished
          // rather than spacious.
          alignment: const AlignmentDirectional(0, -0.55),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.gutter,
              vertical: spacing.xl,
            ),
            child: ConstrainedBox(
              // Caps the form on a tablet: a 700dp-wide text field looks
              // broken, not spacious.
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
                      decoration: const InputDecoration(labelText: 'ایمیل'),
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

                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'شماره موبایل',
                          hintText: '09123456789',
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'شماره موبایل را وارد کنید';
                          if (value.length < 11) return 'شماره موبایل کامل نیست';
                          return null;
                        },
                      ),
                      SizedBox(height: spacing.md),
                    ],

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'رمز عبور',
                        // Rules stated before the user types, not after they
                        // fail.
                        helperText: _isLogin
                            ? null
                            : 'حداقل ۱۰ نویسه، شامل حرف و رقم',
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'رمز عبور را وارد کنید';
                        if (_isLogin) return null;
                        if (value.length < 10) return 'حداقل ۱۰ نویسه';
                        if (!value.contains(RegExp(r'[A-Za-z]'))) {
                          return 'باید حداقل یک حرف داشته باشد';
                        }
                        if (!value.contains(RegExp(r'[0-9]'))) {
                          return 'باید حداقل یک رقم داشته باشد';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing.xl),

                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
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
                    SizedBox(height: spacing.sm),

                    TextButton(
                      onPressed: _busy ? null : _toggleMode,
                      child: Text(
                        _isLogin ? 'حساب ندارم' : 'حساب دارم',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wordmark instead of a flag emoji. "Deutsch" in the display face, "Mate" set
/// lighter, and a hairline rule beneath - the app's name is the only branding
/// it needs.
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
        SizedBox(height: context.spacing.sm),
        Container(width: 44, height: 2, color: colors.accent),
      ],
    );
  }
}
