// lib/pages/customer_dashboard_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({Key? key}) : super(key: key);

  @override
  State<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends State<CustomerDashboardPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _role;
  String? _name;
  String? _avatarUrl;

  DateTime? _createdAt;
  DateTime? _lastLogin;

  int _newOrders = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;
  int _waitingOrders = 0;
  int _pendingApplications = 0;
  int _pendingPayments = 0;
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

    return 'customer';
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

  Future<Map<String, dynamic>?> _getRecordData(
    String collection,
    String? id,
  ) async {
    if (id == null || id.isEmpty) return null;

    try {
      final record = await PocketBaseService.instance.pb
          .collection(collection)
          .getOne(id);

      return {
        'id': record.id,
        'created': record.get<String>('created') ?? '',
        ...record.data,
      };
    } catch (_) {
      return null;
    }
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

      _avatarUrl = _fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      _role = _roleFromUser(user.data);

      _createdAt =
          DateTime.tryParse(user.get<String>('created') ?? '')?.toLocal();

      _lastLogin =
          DateTime.tryParse(
            user.data['last_login'] as String? ?? '',
          )?.toLocal();

      final ordersResult = await pb
          .collection('orders')
          .getList(page: 1, perPage: 200);

      final myOrders =
          ordersResult.items.where((order) {
            final customerId = _relationId(order.data['customer_id']);
            return customerId == userId;
          }).toList();

      myOrders.sort((a, b) {
        final da = DateTime.tryParse(a.get<String>('created') ?? '');
        final db = DateTime.tryParse(b.get<String>('created') ?? '');

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

      _waitingOrders =
          myOrders.where((order) {
            final executorId = _relationId(order.data['executor_id']);
            return executorId == null;
          }).length;

      if (_lastLogin != null) {
        _newOrders =
            myOrders.where((order) {
              final created =
                  DateTime.tryParse(
                    order.get<String>('created') ?? '',
                  )?.toLocal();

              if (created == null) return false;

              return created.isAfter(_lastLogin!);
            }).length;
      } else {
        _newOrders = 0;
      }

      _pendingApplications = await _countPendingApplications(userId);
      _pendingPayments = await _countPendingPayments(userId);

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
      _error = 'Ошибка загрузки личного кабинета: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<int> _countPendingApplications(String userId) async {
    final pb = PocketBaseService.instance.pb;

    final appsResult = await pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    var count = 0;

    for (final app in appsResult.items) {
      final status = app.data['status']?.toString().trim().toLowerCase();
      if (status != 'pending') continue;

      final orderId = _relationId(app.data['order_id']);
      final order = await _getRecordData('orders', orderId);
      final customerId = _relationId(order?['customer_id']);

      if (customerId == userId) {
        count++;
      }
    }

    return count;
  }

  Future<int> _countPendingPayments(String userId) async {
    final pb = PocketBaseService.instance.pb;

    final paymentsResult = await pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    var count = 0;

    for (final payment in paymentsResult.items) {
      final status = payment.data['status']?.toString().trim().toLowerCase();
      if (status != 'pending') continue;

      final taskId = _relationId(payment.data['task_id']);
      final task = await _getRecordData('tasks', taskId);
      final orderId = _relationId(task?['order_id']);
      final order = await _getRecordData('orders', orderId);
      final customerId = _relationId(order?['customer_id']);

      if (customerId == userId) {
        count++;
      }
    }

    return count;
  }

  String get _daysText {
    if (_daysOnProject <= 0) return 'Первый день на платформе';
    return 'С вами уже $_daysOnProject дн.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(
                role: _role!,
                displayName: _name!,
                avatarUrl: _avatarUrl,
              )
              : null,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadDashboard)
                  : Column(
                    children: [
                      AppTopBar(
                        title: 'Личный кабинет',
                        subtitle: 'Панель заказчика',
                        onMenu: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        onRefresh: _loadDashboard,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadDashboard,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                            children: [
                              _WelcomeCard(
                                name: _name ?? 'Заказчик',
                                avatarUrl: _avatarUrl,
                                daysText: _daysText,
                              ),
                              const SizedBox(height: 12),
                              _StatsCard(
                                totalOrders: _totalOrders,
                                activeOrders: _activeOrders,
                                waitingOrders: _waitingOrders,
                                newOrders: _newOrders,
                                pendingApplications: _pendingApplications,
                                pendingPayments: _pendingPayments,
                              ),
                              const SizedBox(height: 12),
                              _QuickActionsCard(
                                onCreateOrder: () async {
                                  await context.push('/customer/create');
                                  await _loadDashboard();
                                },
                                onOrders: () => context.go('/orders'),
                                onApplications: () {
                                  context.go('/customer/applications');
                                },
                                onSupport: () => context.go('/support'),
                              ),
                              const SizedBox(height: 12),
                              const _InfoCard(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String daysText;

  const _WelcomeCard({
    required this.name,
    required this.avatarUrl,
    required this.daysText,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: avatarUrl, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Добро пожаловать', style: AppTextStyles.caption),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(daysText, style: AppTextStyles.small),
              ],
            ),
          ),
          const AppStatusPill(
            text: 'Заказчик',
            color: AppColors.accent,
            icon: CupertinoIcons.person_crop_circle,
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int totalOrders;
  final int activeOrders;
  final int waitingOrders;
  final int newOrders;
  final int pendingApplications;
  final int pendingPayments;

  const _StatsCard({
    required this.totalOrders,
    required this.activeOrders,
    required this.waitingOrders,
    required this.newOrders,
    required this.pendingApplications,
    required this.pendingPayments,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Статистика'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Всего',
                  value: totalOrders.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.work_outline_rounded,
                  label: 'Активные',
                  value: activeOrders.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Ожидают',
                  value: waitingOrders.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.fiber_new_rounded,
                  label: 'Новые',
                  value: newOrders.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Заявки',
                  value: pendingApplications.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.payments_rounded,
                  label: 'Оплаты',
                  value: pendingPayments.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.cardTitle),
                Text(
                  label,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onCreateOrder;
  final VoidCallback onOrders;
  final VoidCallback onApplications;
  final VoidCallback onSupport;

  const _QuickActionsCard({
    required this.onCreateOrder,
    required this.onOrders,
    required this.onApplications,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: 'Быстрые действия'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCreateOrder,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Создать заказ'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOrders,
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Мои заказы'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onApplications,
            icon: const Icon(Icons.assignment_ind_outlined),
            label: const Text('Заявки и оплаты'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSupport,
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Поддержка'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              CupertinoIcons.info,
              color: AppColors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Создайте заказ, дождитесь заявок исполнителей, примите подходящую заявку и продолжайте работу в чате задачи.',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
