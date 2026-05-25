// lib/pages/log_in_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class LogInPage extends StatefulWidget {
  const LogInPage({Key? key}) : super(key: key);

  @override
  State<LogInPage> createState() => _LogInPageState();
}

class _LogInPageState extends State<LogInPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _roleByEmailFallback(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' ||
        normalized == 'dev1@test.local' ||
        normalized == '1') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' ||
        normalized == 'dev3@test.local' ||
        normalized == '3') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' ||
        normalized == 'dev2@test.local' ||
        normalized == '2') {
      return 'executor';
    }

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
      await _showAlert('Заполните логин и пароль');
      return;
    }

    var loginEmail = email;
    var loginPassword = pass;

    if (email == '1' && pass == '1') {
      loginEmail = 'customer@test.ru';
      loginPassword = '12345678';
    } else if (email == '2' && pass == '2') {
      loginEmail = 'executor@test.ru';
      loginPassword = '12345678';
    } else if (email == '3' && pass == '3') {
      loginEmail = 'support@test.ru';
      loginPassword = '12345678';
    }

    setState(() => _isLoading = true);

    try {
      final service = PocketBaseService.instance;
      final auth = await service.login(email: loginEmail, password: loginPassword);

      String role = _normalizeRole(auth.record.data['role'], loginEmail);

      final userId = service.currentUserId;
      if (userId != null) {
        try {
          final user = await service.pb.collection('users').getOne(userId);
          role = _normalizeRole(user.data['role'], loginEmail);
        } catch (_) {
          role = _roleByEmailFallback(loginEmail);
        }
      }

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

  void _fillDevAccount(String login, String password) {
    setState(() {
      _emailCtrl.text = login;
      _passCtrl.text = password;
    });
  }

  Future<void> _showAlert(String message) {
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ошибка входа'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ОК'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _AuthLogoBlock(
                    title: 'Вход',
                    subtitle: 'Фриланс-платформа',
                  ),
                  const SizedBox(height: 20),
                  _LoginFormCard(
                    emailCtrl: _emailCtrl,
                    passCtrl: _passCtrl,
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    onTogglePassword: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    onSubmit: _signIn,
                  ),
                  const SizedBox(height: 12),
                  _DevAccountsCard(
                    disabled: _isLoading,
                    onSelectCustomer: () => _fillDevAccount('1', '1'),
                    onSelectExecutor: () => _fillDevAccount('2', '2'),
                    onSelectSupport: () => _fillDevAccount('3', '3'),
                  ),
                  const SizedBox(height: 12),
                  _RegisterLinkCard(
                    disabled: _isLoading,
                    onTap: () => context.go('/register'),
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

class _AuthLogoBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AuthLogoBlock({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Image.asset(
            'assets/logo-image.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.work_outline_rounded,
                color: AppColors.accent,
                size: 42,
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.pageTitle.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: AppTextStyles.body),
      ],
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _LoginFormCard({
    required this.emailCtrl,
    required this.passCtrl,
    required this.isLoading,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: 'Авторизация'),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Логин или email',
              hintText: 'customer@test.ru или 1',
              prefixIcon: Icon(CupertinoIcons.mail),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passCtrl,
            enabled: !isLoading,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => isLoading ? null : onSubmit(),
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: InputDecoration(
              labelText: 'Пароль',
              hintText: 'Введите пароль',
              prefixIcon: const Icon(CupertinoIcons.lock),
              suffixIcon: IconButton(
                onPressed: isLoading ? null : onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onSubmit,
            icon:
                isLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(CupertinoIcons.arrow_right_circle),
            label: Text(isLoading ? 'Входим...' : 'Войти'),
          ),
        ],
      ),
    );
  }
}

class _DevAccountsCard extends StatelessWidget {
  final bool disabled;
  final VoidCallback onSelectCustomer;
  final VoidCallback onSelectExecutor;
  final VoidCallback onSelectSupport;

  const _DevAccountsCard({
    required this.disabled,
    required this.onSelectCustomer,
    required this.onSelectExecutor,
    required this.onSelectSupport,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Быстрый вход'),
          const SizedBox(height: 8),
          Text(
            'Временные аккаунты для разработки.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DevAccountButton(
                  label: '1 / 1',
                  subtitle: 'Заказчик',
                  icon: CupertinoIcons.person_crop_circle,
                  disabled: disabled,
                  onTap: onSelectCustomer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DevAccountButton(
                  label: '2 / 2',
                  subtitle: 'Исполнитель',
                  icon: Icons.engineering_outlined,
                  disabled: disabled,
                  onTap: onSelectExecutor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DevAccountButton(
                  label: '3 / 3',
                  subtitle: 'Поддержка',
                  icon: Icons.support_agent_rounded,
                  disabled: disabled,
                  onTap: onSelectSupport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevAccountButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool disabled;
  final VoidCallback onTap;

  const _DevAccountButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: disabled ? null : onTap,
      radius: AppRadii.md,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RegisterLinkCard extends StatelessWidget {
  final bool disabled;
  final VoidCallback onTap;

  const _RegisterLinkCard({required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(child: Text('Нет аккаунта?', style: AppTextStyles.body)),
          TextButton(
            onPressed: disabled ? null : onTap,
            child: const Text('Зарегистрироваться'),
          ),
        ],
      ),
    );
  }
}
