// lib/pages/customer_create_order_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class CustomerCreateOrderPage extends StatefulWidget {
  const CustomerCreateOrderPage({Key? key}) : super(key: key);

  @override
  State<CustomerCreateOrderPage> createState() =>
      _CustomerCreateOrderPageState();
}

class _CustomerCreateOrderPageState extends State<CustomerCreateOrderPage> {
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  DateTime? _deadline;
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _frameworks = [];
  List<Map<String, dynamic>> _languages = [];

  String? _selectedFwId;
  String? _selectedLgId;

  String? _role;
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() => _loading = true);

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await pb.collection('users').getOne(userId);

      _role = user.data['role'] as String? ?? 'customer';
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';
      _photo = user.data['photo'] as String?;

      final fwRecords = await pb
          .collection('frameworks')
          .getFullList(sort: 'name');

      final lgRecords = await pb
          .collection('languages')
          .getFullList(sort: 'name');

      _frameworks =
          fwRecords.map((record) {
            return {
              'id': record.id,
              'name': record.data['name'] as String? ?? '',
            };
          }).toList();

      _languages =
          lgRecords.map((record) {
            return {
              'id': record.id,
              'name': record.data['name'] as String? ?? '',
            };
          }).toList();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: Theme.of(ctx).colorScheme.secondary,
                onPrimary: Colors.white,
                surface: Theme.of(ctx).colorScheme.secondary,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submitOrder() async {
    final desc = _descCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    if (desc.isEmpty ||
        _selectedFwId == null ||
        _selectedLgId == null ||
        _deadline == null ||
        price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля и укажите корректную цену'),
        ),
      );
      return;
    }

    final service = PocketBaseService.instance;
    final userId = service.currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await service.pb
          .collection('orders')
          .create(
            body: {
              'customer_id': userId,
              'framework_id': _selectedFwId,
              'language_id': _selectedLgId,
              'task_description': desc,
              'deadline': _deadline!.toIso8601String(),
              'price': price,
            },
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при создании заказа: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      appBar: AppBar(
        backgroundColor: cs.primary,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.playlist_add, size: 24),
            const SizedBox(width: 8),
            Text('Create order', style: TextStyle(color: cs.onPrimary)),
          ],
        ),
      ),
      backgroundColor: cs.primaryContainer,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: TextStyle(color: cs.onPrimaryContainer),
              decoration: InputDecoration(
                hintText: 'Описание задачи',
                hintStyle: TextStyle(
                  color: cs.onPrimaryContainer.withOpacity(0.6),
                ),
                filled: true,
                fillColor: cs.secondaryContainer,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: cs.secondary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: cs.onPrimaryContainer),
              decoration: InputDecoration(
                hintText: 'Price, USD',
                hintStyle: TextStyle(
                  color: cs.onPrimaryContainer.withOpacity(0.6),
                ),
                filled: true,
                fillColor: cs.secondaryContainer,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: cs.secondary),
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: Icon(
                  Icons.attach_money,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedFwId,
              items:
                  _frameworks
                      .map(
                        (fw) => DropdownMenuItem<String>(
                          value: fw['id'] as String,
                          child: Text(fw['name'] as String),
                        ),
                      )
                      .toList(),
              onChanged:
                  _saving ? null : (v) => setState(() => _selectedFwId = v),
              decoration: InputDecoration(
                hintText: 'Framework',
                hintStyle: TextStyle(
                  color: cs.onPrimaryContainer.withOpacity(0.6),
                ),
                filled: true,
                fillColor: cs.secondaryContainer,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: cs.secondary),
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: Icon(
                  Icons.developer_mode,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedLgId,
              items:
                  _languages
                      .map(
                        (lg) => DropdownMenuItem<String>(
                          value: lg['id'] as String,
                          child: Text(lg['name'] as String),
                        ),
                      )
                      .toList(),
              onChanged:
                  _saving ? null : (v) => setState(() => _selectedLgId = v),
              decoration: InputDecoration(
                hintText: 'Language',
                hintStyle: TextStyle(
                  color: cs.onPrimaryContainer.withOpacity(0.6),
                ),
                filled: true,
                fillColor: cs.secondaryContainer,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: cs.secondary),
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: Icon(Icons.language, color: cs.onPrimaryContainer),
              ),
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: _saving ? null : _pickDeadline,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Deadline',
                  labelStyle: TextStyle(
                    color: cs.onPrimaryContainer.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: cs.secondaryContainer,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: cs.secondary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _deadline == null ? 'Не выбран' : _dateFmt.format(_deadline!),
                  style: TextStyle(color: cs.onPrimaryContainer),
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _saving ? null : _submitOrder,
              icon:
                  _saving
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.check_circle_outline),
              label: Text(_saving ? 'Creating...' : 'Create order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: cs.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
