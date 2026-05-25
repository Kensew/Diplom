// lib/pages/support_create_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class SupportCreatePage extends StatefulWidget {
  const SupportCreatePage({Key? key}) : super(key: key);

  @override
  State<SupportCreatePage> createState() => _SupportCreatePageState();
}

class _SupportCreatePageState extends State<SupportCreatePage> {
  final _reasonCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _role;
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadDrawerData();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String? _firstFileName(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) {
        final trimmed = first.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
    }

    return null;
  }

  String? _fileUrl({
    required String collectionName,
    required String recordId,
    required dynamic fileValue,
  }) {
    final fileName = _firstFileName(fileValue);
    if (fileName == null) return null;

    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }

    final encodedName = Uri.encodeComponent(fileName);

    return '${PocketBaseService.baseUrl}/api/files/$collectionName/$recordId/$encodedName';
  }

  String _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' || normalized == 'dev1@test.local') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' || normalized == 'dev3@test.local') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' || normalized == 'dev2@test.local') {
      return 'executor';
    }

    return 'executor';
  }

  String _roleFromUser(Map<String, dynamic> data) {
    final email = data['email']?.toString() ?? '';
    final rawRole = data['role']?.toString().trim().toLowerCase();

    if (rawRole == 'customer' ||
        rawRole == 'support' ||
        rawRole == 'executor') {
      return rawRole!;
    }

    return _roleFallbackByEmail(email);
  }

  Future<void> _loadDrawerData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final profile = await service.pb.collection('users').getOne(userId);

      _role = _roleFromUser(profile.data);
      _name =
          profile.data['name'] as String? ??
          profile.data['email'] as String? ??
          'User';

      _photo = _fileUrl(
        collectionName: 'users',
        recordId: profile.id,
        fileValue: profile.data['photo'],
      );
    } catch (e) {
      _error = 'Не удалось загрузить профиль: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    final text = _reasonCtrl.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Опишите проблему')));
      return;
    }

    setState(() => _saving = true);

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      await service.pb
          .collection('support_requests')
          .create(body: {'user_id': userId, 'reason': text});

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Обращение создано')));

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать обращение: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/support');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadDrawerData)
                  : Column(
                    children: [
                      AppTopBar(
                        title: 'Новое обращение',
                        subtitle: 'Опишите вопрос для поддержки',
                        onBack: _goBack,
                      ),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          children: [
                            _SupportIntroCard(
                              name: _name ?? 'Пользователь',
                              avatarUrl: _photo,
                              role: _role ?? 'executor',
                            ),
                            const SizedBox(height: 12),
                            _SupportRequestFormCard(
                              controller: _reasonCtrl,
                              saving: _saving,
                            ),
                            const SizedBox(height: 12),
                            _SubmitCard(saving: _saving, onSubmit: _submit),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _SupportIntroCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String role;

  const _SupportIntroCard({
    required this.name,
    required this.avatarUrl,
    required this.role,
  });

  String get _roleLabel {
    switch (role) {
      case 'customer':
        return 'Заказчик';
      case 'support':
        return 'Поддержка';
      case 'executor':
        return 'Исполнитель';
      default:
        return 'Пользователь';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(_roleLabel, style: AppTextStyles.caption),
              ],
            ),
          ),
          const AppStatusPill(
            text: 'support',
            color: AppColors.accent,
            icon: Icons.support_agent_rounded,
          ),
        ],
      ),
    );
  }
}

class _SupportRequestFormCard extends StatelessWidget {
  final TextEditingController controller;
  final bool saving;

  const _SupportRequestFormCard({
    required this.controller,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Описание обращения'),
          const SizedBox(height: 12),
          Text(
            'Опишите проблему, вопрос или ситуацию. После создания обращения можно продолжить диалог в чате поддержки.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !saving,
            minLines: 5,
            maxLines: 10,
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Текст обращения',
              hintText: 'Например: не получается открыть чат задачи...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitCard extends StatelessWidget {
  final bool saving;
  final VoidCallback onSubmit;

  const _SubmitCard({required this.saving, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: saving ? null : onSubmit,
            icon:
                saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(CupertinoIcons.paperplane_fill),
            label: Text(saving ? 'Создаём обращение...' : 'Создать обращение'),
          ),
          const SizedBox(height: 10),
          Text(
            'Обращение появится в разделе поддержки, после этого можно открыть чат.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
