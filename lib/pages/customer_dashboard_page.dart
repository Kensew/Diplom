// lib/pages/customer_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({Key? key}) : super(key: key);

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  String? _role;
  String? _name;
  String? _avatarUrl;

  DateTime? _createdAt;
  DateTime? _lastLogin;

  int _newOrders = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;
  int _daysOnProject = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String? _relationId(dynamic value) {
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

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await pb.collection('users').getOne(userId);

      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';
      _avatarUrl = user.data['photo'] as String?;
      _role = user.data['role'] as String? ?? 'customer';

      _createdAt = DateTime.tryParse(user.created)?.toLocal();

      _lastLogin =
          DateTime.tryParse(
            user.data['last_login'] as String? ?? '',
          )?.toLocal();

      final orderResult = await pb
          .collection('orders')
          .getList(page: 1, perPage: 200);

      final myOrders =
          orderResult.items.where((order) {
            final customerId = _relationId(order.data['customer_id']);
            return customerId == userId;
          }).toList();

      myOrders.sort((a, b) {
        final da = DateTime.tryParse(a.created);
        final db = DateTime.tryParse(b.created);

        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;

        return db.compareTo(da);
      });

      _totalOrders = myOrders.length;

      _activeOrders =
          myOrders.where((order) {
            final executorId = _relationId(order.data['executor_id']);
            return executorId != null;
          }).length;

      if (_lastLogin != null) {
        _newOrders =
            myOrders.where((order) {
              final created = DateTime.tryParse(order.created)?.toLocal();
              if (created == null) return false;
              return created.isAfter(_lastLogin!);
            }).length;
      } else {
        _newOrders = 0;
      }

      _daysOnProject =
          _createdAt == null
              ? 0
              : DateTime.now().difference(_createdAt!).inDays;

      await pb
          .collection('users')
          .update(
            userId,
            body: {'last_login': DateTime.now().toIso8601String()},
          );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: cs.background,
        body: Center(
          child: Text(
            'Ошибка: $_error',
            style: tt.bodyLarge?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.background,
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(
                role: _role!,
                displayName: _name!,
                avatarUrl: _avatarUrl,
              )
              : null,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0.5,
        title: Text(
          'Личный кабинет',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    _avatarUrl != null && _avatarUrl!.trim().isNotEmpty
                        ? CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(_avatarUrl!),
                        )
                        : CircleAvatar(
                          radius: 26,
                          backgroundColor: cs.primaryContainer,
                          child: Icon(
                            Icons.person,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Добро пожаловать, $_name!',
                            style: tt.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _daysOnProject > 0
                                ? 'С вами уже $_daysOnProject дней'
                                : 'Первый день на платформе',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Статистика заказчика',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: GridView(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                              children: [
                                _StatCard(
                                  icon: Icons.fiber_new,
                                  label: 'Новые заявки',
                                  value: _newOrders,
                                  cs: cs,
                                  tt: tt,
                                  accentColor: cs.primary,
                                ),
                                _StatCard(
                                  icon: Icons.list_alt,
                                  label: 'Всего заявок',
                                  value: _totalOrders,
                                  cs: cs,
                                  tt: tt,
                                  accentColor: cs.secondary,
                                ),
                                _StatCard(
                                  icon: Icons.work_outline,
                                  label: 'Активных заказов',
                                  value: _activeOrders,
                                  cs: cs,
                                  tt: tt,
                                  accentColor: cs.tertiary,
                                ),
                                _StatCard(
                                  icon: Icons.calendar_today,
                                  label: 'Дней на проекте',
                                  value: _daysOnProject,
                                  cs: cs,
                                  tt: tt,
                                  accentColor: cs.primaryContainer,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Быстрые действия',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Создайте новый заказ или посмотрите текущие.',
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(child: _PromoCard(cs: cs, tt: tt)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Новый заказ'),
                              onPressed: () => context.push('/customer/create'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.secondary,
                                foregroundColor: cs.onSecondary,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: const Text('Мои заказы'),
                              onPressed: () => context.go('/orders'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                side: BorderSide(color: cs.primary, width: 1.6),
                                foregroundColor: cs.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final ColorScheme cs;
  final TextTheme tt;
  final Color accentColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.16),
            cs.primaryContainer.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surface,
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: tt.titleLarge?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _PromoCard({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.campaign_rounded, size: 36, color: cs.primary),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              'Место для рекламы',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
