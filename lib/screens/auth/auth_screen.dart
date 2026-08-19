import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 پکیج جدید
import '/main_container_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
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

  // 💾 تابع ذخیره‌سازی سازگار با وب و موبایل
  Future<void> _saveUserToJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // خواندن لیست قبلی از حافظه
      String? existingUsersJson = prefs.getString('users_data');
      List<dynamic> usersList = [];

      if (existingUsersJson != null && existingUsersJson.isNotEmpty) {
        usersList = jsonDecode(existingUsersJson);
      }

      // کاربر جدید
      Map<String, String> newUser = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
      };

      usersList.add(newUser);

      // ذخیره مجدد به صورت رشته JSON
      await prefs.setString('users_data', jsonEncode(usersList));

      print('✅ کاربر با موفقیت ذخیره شد!');
      print('📄 کل کاربران ذخیره‌شده: ${prefs.getString('users_data')}');
    } catch (e) {
      print('❌ خطا در ذخیره‌سازی: $e');
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (!isLogin) {
        await _saveUserToJson();
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainContainerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin ? 'ورود' : 'ثبت نام',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),

                if (!isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'نام و نام خانوادگی',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'لطفاً نام را وارد کنید' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'لطفاً ایمیل را وارد کنید' : null,
                ),
                const SizedBox(height: 16),

                if (!isLogin) ...[
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'شماره موبایل',
                      hintText: '09123456789',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'لطفاً شماره موبایل را وارد کنید';
                      }
                      if (value.length < 11) {
                        return 'شماره موبایل معتبر نیست';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'رمز عبور',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'لطفاً رمز عبور را وارد کنید' : null,
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(isLogin ? 'ورود' : 'ثبت نام'),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(
                    isLogin
                        ? 'حساب کاربری ندارید؟ ثبت نام کنید'
                        : 'حساب کاربری دارید؟ وارد شوید',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}