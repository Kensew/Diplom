// lib/pages/support_create_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class SupportCreatePage extends StatefulWidget {
  const SupportCreatePage({Key? key}) : super(key: key);

  @override
  State<SupportCreatePage> createState() => _SupportCreatePageState();
}

class _SupportCreatePageState extends State<SupportCreatePage> {
  final _reasonCtrl = TextEditingController();

  bool _loading = false;
  String? _role;
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadDrawerData();
  }

  Future<void> _loadDrawerData() async {
    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) return;

      final profile = await service.pb.collection('users').getOne(userId);

      if (!mounted) return;

      setState(() {
        _role = profile.data['role'] as String? ?? 'executor';
        _name =
            profile.data['name'] as String? ??
            profile.data['email'] as String? ??
            'User';
        _photo = profile.data['photo'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    final text = _reasonCtrl.text.trim();

    if (text.isEmpty) return;

    setState(() => _loading = true);

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      await service.pb
          .collection('support_requests')
          .create(body: {'user_id': userId, 'reason': text});

      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось создать запрос: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.support_agent_outlined, color: cs.onSurface),
            const SizedBox(width: 8),
            Text(
              'New Support Request',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
      backgroundColor: cs.surface,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _reasonCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Опишите вашу проблему…',
                filled: true,
                fillColor: cs.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon:
                    _loading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.send),
                label: Text(_loading ? 'Sending...' : 'Submit'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
