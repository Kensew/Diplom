// lib/pages/log_in_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class LogInPage extends StatefulWidget {
  const LogInPage({Key? key}) : super(key: key);

  @override
  State<LogInPage> createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLoading = false;

  String _roleByEmailFallback(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru') return 'customer';
    if (normalized == 'support@test.ru') return 'support';
    if (normalized == 'executor@test.ru') return 'executor';

    return 'executor';
  }

  String _normalizeRole(dynamic value, String email) {
    final role = value?.toString().trim().toLowerCase();

    if (role == 'customer' || role == 'support' || role == 'executor') {
      return role!;
    }

    return _roleByEmailFallback(email);
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      await _showAlert('Заполните email и пароль');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = PocketBaseService.instance;

      final auth = await service.login(email: email, password: pass);

      String role = _normalizeRole(auth.record.data['role'], email);

      final userId = service.currentUserId;
      if (userId != null) {
        try {
          final user = await service.pb.collection('users').getOne(userId);
          role = _normalizeRole(user.data['role'], email);
        } catch (_) {
          role = _roleByEmailFallback(email);
        }
      }

      debugPrint('LOGIN EMAIL=$email ROLE=$role');

      if (!mounted) return;

      if (role == 'customer') {
        context.go('/customer');
      } else if (role == 'support') {
        context.go('/support');
      } else {
        context.go('/tasks');
      }
    } catch (e) {
      if (!mounted) return;
      await _showAlert('Ошибка входа: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAlert(String message) {
    return showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ошибка входа'),
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(78, 107, 44, 1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 40),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Image.asset('assets/logo-image.png'),
                ),
                const SizedBox(height: 32),
                _buildField(
                  controller: _emailCtrl,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _passCtrl,
                  hint: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Log In',
                              style: TextStyle(fontSize: 18),
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : () => context.go('/register'),
                  child: const Text(
                    'Don’t have an account? Sign Up',
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

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white24,
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
}
