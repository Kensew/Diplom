// lib/pages/edit_profile_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  final _picker = ImagePicker();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  DateTime? _birthDate;
  XFile? _pickedImage;

  bool _isSaving = false;
  bool _loading = true;
  String? _error;

  String? _role;
  String? _email;
  String? _avatarUrl;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
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

  Future<void> _loadCurrentProfile() async {
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

      final user = await service.pb.collection('users').getOne(userId);

      _userId = user.id;
      _nameCtrl.text = user.data['name'] as String? ?? '';
      _descCtrl.text = user.data['description'] as String? ?? '';
      _role = _roleFromUser(user.data);
      _email = user.data['email'] as String?;

      _avatarUrl = _fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final birthRaw = user.data['birth_date'] as String?;
      final birth = DateTime.tryParse(birthRaw ?? '');

      if (birth != null) {
        _birthDate = birth.toLocal();
        _dateCtrl.text = _dateFmt.format(_birthDate!);
      }
    } catch (e) {
      _error = 'Ошибка загрузки профиля: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (image == null) return;

    setState(() {
      _pickedImage = image;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _birthDate = picked;
      _dateCtrl.text = _dateFmt.format(picked);
    });
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

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите имя')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final files = <http.MultipartFile>[];

      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();

        files.add(
          http.MultipartFile.fromBytes(
            'photo',
            bytes,
            filename: _pickedImage!.name,
          ),
        );
      }

      await service.pb
          .collection('users')
          .update(
            userId,
            body: {
              'name': name,
              'description': _descCtrl.text.trim(),
              'birth_date': _birthDate?.toIso8601String(),
              'age': _calculateAge(_birthDate),
            },
            files: files,
          );

      await service.refreshUser();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Профиль сохранён')));

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при сохранении: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/account');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer:
          (_role != null && _nameCtrl.text.trim().isNotEmpty)
              ? AppDrawer(
                role: _role!,
                displayName: _nameCtrl.text.trim(),
                avatarUrl: _avatarPreviewUrl,
              )
              : null,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(
                    message: _error!,
                    onRetry: _loadCurrentProfile,
                  )
                  : Column(
                    children: [
                      AppTopBar(
                        title: 'Редактировать профиль',
                        subtitle: 'Имя, описание, дата рождения и фото',
                        onBack: _goBack,
                      ),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          children: [
                            _AvatarEditCard(
                              name:
                                  _nameCtrl.text.trim().isEmpty
                                      ? 'Пользователь'
                                      : _nameCtrl.text.trim(),
                              email: _email ?? '',
                              avatarUrl: _avatarUrl,
                              pickedImage: _pickedImage,
                              onPickAvatar: _isSaving ? null : _pickAvatar,
                            ),
                            const SizedBox(height: 12),
                            _ProfileFormCard(
                              nameCtrl: _nameCtrl,
                              descCtrl: _descCtrl,
                              dateCtrl: _dateCtrl,
                              saving: _isSaving,
                              onPickDate: _pickDate,
                            ),
                            const SizedBox(height: 12),
                            _SaveCard(saving: _isSaving, onSave: _saveProfile),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  String? get _avatarPreviewUrl {
    if (_pickedImage != null) return null;
    return _avatarUrl;
  }
}

class _AvatarEditCard extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final XFile? pickedImage;
  final VoidCallback? onPickAvatar;

  const _AvatarEditCard({
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.pickedImage,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _AvatarPreview(avatarUrl: avatarUrl, pickedImage: pickedImage),
          const SizedBox(height: 12),
          Text(
            name,
            style: AppTextStyles.cardTitle,
            textAlign: TextAlign.center,
          ),
          if (email.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              email,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onPickAvatar,
            icon: const Icon(CupertinoIcons.photo),
            label: const Text('Выбрать фото'),
          ),
        ],
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String? avatarUrl;
  final XFile? pickedImage;

  const _AvatarPreview({required this.avatarUrl, required this.pickedImage});

  @override
  Widget build(BuildContext context) {
    if (pickedImage != null) {
      return FutureBuilder<List<int>>(
        future: pickedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              width: 84,
              height: 84,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return ClipOval(
            child: Image.memory(
              snapshot.data! as dynamic,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          );
        },
      );
    }

    return AppProfileAvatar(avatarUrl: avatarUrl, size: 84);
  }
}

class _ProfileFormCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController dateCtrl;
  final bool saving;
  final VoidCallback onPickDate;

  const _ProfileFormCard({
    required this.nameCtrl,
    required this.descCtrl,
    required this.dateCtrl,
    required this.saving,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Данные профиля'),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            enabled: !saving,
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
            readOnly: true,
            enabled: !saving,
            onTap: saving ? null : onPickDate,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Дата рождения',
              hintText: 'Выберите дату',
              prefixIcon: Icon(CupertinoIcons.calendar),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            enabled: !saving,
            minLines: 4,
            maxLines: 8,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Описание',
              hintText: 'Расскажите о себе',
              alignLabelWithHint: true,
              prefixIcon: Icon(CupertinoIcons.text_alignleft),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveCard extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;

  const _SaveCard({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: saving ? null : onSave,
            icon:
                saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Сохраняем...' : 'Сохранить профиль'),
          ),
          const SizedBox(height: 10),
          Text(
            'Фото сохраняется в поле users.photo в PocketBase.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
