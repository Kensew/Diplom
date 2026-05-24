// lib/pages/order_apply_page.dart

import 'package:flutter/material.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class OrderApplyPage extends StatefulWidget {
  final String orderId;

  const OrderApplyPage({required this.orderId, Key? key}) : super(key: key);

  @override
  State<OrderApplyPage> createState() => _OrderApplyPageState();
}

class _OrderApplyPageState extends State<OrderApplyPage> {
  bool _loading = false;
  bool _applied = false;
  String? _error;

  String? _role;
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadDrawerData();
    _checkIfAlreadyApplied();
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

  Future<void> _checkIfAlreadyApplied() async {
    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) return;

      final applications = await service.pb
          .collection('applications')
          .getList(
            page: 1,
            perPage: 1,
            filter: 'order_id = "${widget.orderId}" && executor_id = "$userId"',
          );

      if (!mounted) return;

      setState(() {
        _applied = applications.items.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _apply() async {
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

      await service.pb
          .collection('applications')
          .create(
            body: {
              'order_id': widget.orderId,
              'executor_id': userId,
              'status': 'pending',
            },
          );

      if (!mounted) return;

      setState(() => _applied = true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : const SizedBox.shrink(),
      appBar: AppBar(title: const Text('Заявка на заказ')),
      body: Center(
        child:
            _applied
                ? const Text('Заявка отправлена. Ожидается решение заказчика.')
                : _loading
                ? const CircularProgressIndicator()
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _apply,
                      child: const Text('Подать заявку'),
                    ),
                  ],
                ),
      ),
    );
  }
}
