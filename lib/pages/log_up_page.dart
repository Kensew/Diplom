// lib/pages/log_up_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';

class LogUpPage extends StatefulWidget {
  const LogUpPage({Key? key}) : super(key: key);

  @override
  State<LogUpPage> createState() => _LogUpPageState();
}

class _LogUpPageState extends State<LogUpPage> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  DateTime? _birthDate;
  bool _isLoading = false;
  String _role = 'executor';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _dateCtrl.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _showAlert(String message) {
    return showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ошибка регистрации'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _signUp() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if ([email, name, pass, confirm].any((s) => s.isEmpty)) {
      await _showAlert('Заполните все обязательные поля');
      return;
    }

    if (pass.length < 8) {
      await _showAlert('Пароль должен быть не короче 8 символов');
      return;
    }

    if (pass != confirm) {
      await _showAlert('Пароли не совпадают');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await PocketBaseService.instance.register(
        email: email,
        password: pass,
        name: name,
        role: _role,
        birthDate: _birthDate,
      );

      if (!mounted) return;

      await _showAlert('Аккаунт создан. Теперь войдите в систему.');

      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      await _showAlert('Ошибка регистрации: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String hint,
    bool obscure = false,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      readOnly: onTap != null,
      onTap: onTap,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset('assets/logo-image.png'),
                ),
                const SizedBox(height: 24),
                _buildField(
                  ctrl: _emailCtrl,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildField(ctrl: _nameCtrl, hint: 'Name'),
                const SizedBox(height: 16),
                _buildField(
                  ctrl: _dateCtrl,
                  hint: 'Birth Date',
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                _buildField(ctrl: _passCtrl, hint: 'Password', obscure: true),
                const SizedBox(height: 16),
                _buildField(
                  ctrl: _confirmCtrl,
                  hint: 'Confirm Password',
                  obscure: true,
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _role,
                      dropdownColor: AppColors.background,
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: 'executor',
                          child: Text('Исполнитель'),
                        ),
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text('Заказчик'),
                        ),
                      ],
                      onChanged:
                          _isLoading
                              ? null
                              : (v) {
                                if (v != null) {
                                  setState(() => _role = v);
                                }
                              },
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 18),
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () => GoRouter.of(context).go('/login'),
                  child: const Text(
                    'Already have an account? Log In',
                    style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
