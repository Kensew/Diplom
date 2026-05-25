// lib/pages/log_up_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

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

  final _dateFmt = DateFormat('dd.MM.yyyy');

  DateTime? _birthDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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

  String _roleLabel(String role) {
    switch (role) {
      case 'customer':
        return 'Заказчик';
      case 'executor':
        return 'Исполнитель';
      default:
        return 'Пользователь';
    }
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;

    final now = DateTime.now();
    var age = now.year - birthDate.year;

    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    return age;
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
        _dateCtrl.text = _dateFmt.format(picked);
      });
    }
  }

  Future<void> _selectRole() async {
    await showAppBottomSheet(
      context: context,
      title: 'Роль',
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          AppBottomSheetOption(
            title: 'Исполнитель',
            selected: _role == 'executor',
            onTap: () {
              Navigator.pop(context);
              setState(() => _role = 'executor');
            },
          ),
          AppBottomSheetOption(
            title: 'Заказчик',
            selected: _role == 'customer',
            onTap: () {
              Navigator.pop(context);
              setState(() => _role = 'customer');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAlert(String message) {
    return showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Регистрация'),
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

  Future<void> _signUp() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if ([email, name, pass, confirm].any((value) => value.isEmpty)) {
      await _showAlert('Заполните email, имя и пароль');
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

      final userId = PocketBaseService.instance.currentUserId;
      if (userId != null && _birthDate != null) {
        try {
          await PocketBaseService.instance.pb
              .collection('users')
              .update(userId, body: {'age': _calculateAge(_birthDate)});
        } catch (_) {}
      }

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
                    title: 'Регистрация',
                    subtitle: 'Создание аккаунта',
                  ),
                  const SizedBox(height: 20),
                  _RegisterFormCard(
                    emailCtrl: _emailCtrl,
                    nameCtrl: _nameCtrl,
                    dateCtrl: _dateCtrl,
                    passCtrl: _passCtrl,
                    confirmCtrl: _confirmCtrl,
                    roleLabel: _roleLabel(_role),
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    onPickDate: _pickDate,
                    onSelectRole: _selectRole,
                    onTogglePassword: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    onToggleConfirm: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                    onSubmit: _signUp,
                  ),
                  const SizedBox(height: 12),
                  _LoginLinkCard(
                    disabled: _isLoading,
                    onTap: () => context.go('/login'),
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

class _RegisterFormCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController dateCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final String roleLabel;
  final bool isLoading;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onPickDate;
  final VoidCallback onSelectRole;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  const _RegisterFormCard({
    required this.emailCtrl,
    required this.nameCtrl,
    required this.dateCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.roleLabel,
    required this.isLoading,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onPickDate,
    required this.onSelectRole,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: 'Данные аккаунта'),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'user@example.com',
              prefixIcon: Icon(CupertinoIcons.mail),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            enabled: !isLoading,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Имя',
              hintText: 'Введите имя',
              prefixIcon: Icon(CupertinoIcons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dateCtrl,
            enabled: !isLoading,
            readOnly: true,
            onTap: isLoading ? null : onPickDate,
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Дата рождения',
              hintText: 'Необязательно',
              prefixIcon: Icon(CupertinoIcons.calendar),
            ),
          ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            onTap: isLoading ? null : onSelectRole,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            radius: AppRadii.sm,
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Роль', style: AppTextStyles.small)),
                Text(
                  roleLabel,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passCtrl,
            enabled: !isLoading,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: InputDecoration(
              labelText: 'Пароль',
              hintText: 'Минимум 8 символов',
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
          const SizedBox(height: 12),
          TextField(
            controller: confirmCtrl,
            enabled: !isLoading,
            obscureText: obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => isLoading ? null : onSubmit(),
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: InputDecoration(
              labelText: 'Повтор пароля',
              hintText: 'Повторите пароль',
              prefixIcon: const Icon(CupertinoIcons.lock_shield),
              suffixIcon: IconButton(
                onPressed: isLoading ? null : onToggleConfirm,
                icon: Icon(
                  obscureConfirm
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
                    : const Icon(CupertinoIcons.check_mark_circled),
            label: Text(
              isLoading ? 'Создаём аккаунт...' : 'Зарегистрироваться',
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginLinkCard extends StatelessWidget {
  final bool disabled;
  final VoidCallback onTap;

  const _LoginLinkCard({required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(child: Text('Уже есть аккаунт?', style: AppTextStyles.body)),
          TextButton(
            onPressed: disabled ? null : onTap,
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }
}
