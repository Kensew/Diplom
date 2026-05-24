// lib/pages/edit_profile_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();

  DateTime? _birthDate;
  bool _isSaving = false;
  bool _loading = true;
  String? _error;

  String? _role;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
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

      _nameCtrl.text = user.data['name'] as String? ?? '';
      _descCtrl.text = user.data['description'] as String? ?? '';
      _photoCtrl.text = user.data['photo'] as String? ?? '';
      _role = user.data['role'] as String? ?? 'executor';

      final birthRaw = user.data['birth_date'] as String?;
      final birth = DateTime.tryParse(birthRaw ?? '');
      if (birth != null) {
        _birthDate = birth;
        _dateCtrl.text = birth.toIso8601String().split('T').first;
      }
    } catch (e) {
      _error = 'Ошибка загрузки профиля: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder:
          (_, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.background,
                onPrimary: Colors.white,
                surface: AppColors.background,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _birthDate = picked;
      _dateCtrl.text = picked.toIso8601String().split('T').first;
    });
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

      await service.pb
          .collection('users')
          .update(
            userId,
            body: {
              'name': name,
              'description': _descCtrl.text.trim(),
              'birth_date': _birthDate?.toIso8601String(),
              'photo': _photoCtrl.text.trim(),
            },
          );

      await service.refreshUser();

      if (!mounted) return;
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

  String? _avatarUrl() {
    final value = _photoCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text('Edit Profile', style: theme.textTheme.headlineLarge),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    final avatarUrl = _avatarUrl();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer:
          (_role != null && _nameCtrl.text.trim().isNotEmpty)
              ? AppDrawer(
                role: _role!,
                displayName: _nameCtrl.text.trim(),
                avatarUrl: avatarUrl,
              )
              : const SizedBox.shrink(),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Edit Profile', style: theme.textTheme.headlineLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.fieldFill,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child:
                    avatarUrl == null
                        ? const Icon(
                          Icons.person,
                          size: 48,
                          color: Colors.white70,
                        )
                        : null,
              ),
              const SizedBox(height: 24),

              _buildField(controller: _nameCtrl, hint: 'Name'),
              const SizedBox(height: 16),

              _buildField(
                controller: _dateCtrl,
                hint: 'Birth Date',
                readOnly: true,
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),

              _buildField(
                controller: _descCtrl,
                hint: 'Description',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              _buildField(controller: _photoCtrl, hint: 'Photo URL'),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child:
                      _isSaving
                          ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text('Save', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.hint),
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
}
