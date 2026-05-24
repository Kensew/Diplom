// lib/pages/customer_home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({Key? key}) : super(key: key);

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _orders = [];
  final _fmt = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
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

      final records = await service.pb
          .collection('orders')
          .getFullList(filter: 'customer_id = "$userId"', sort: '-created');

      _orders =
          records.map((record) {
            return {
              'id': record.id,
              'task_description':
                  record.data['task_description'] as String? ?? '',
              'deadline': record.data['deadline'] as String?,
            };
          }).toList();
    } catch (e) {
      _error = 'Не удалось загрузить заказы: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDeadline(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';
    return _fmt.format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        title: Text(
          'Мои заказы',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: cs.error),
                    ),
                  ),
                )
                : _orders.isEmpty
                ? _EmptyOrdersState(
                  onCreate: () => context.push('/customer/create'),
                )
                : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _orders.length,
                  itemBuilder: (_, i) {
                    final order = _orders[i];

                    return _OrderCard(
                      title: order['task_description'] as String? ?? '—',
                      deadlineText: _formatDeadline(
                        order['deadline'] as String?,
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customer/create'),
        icon: const Icon(Icons.add),
        label: const Text('Новый заказ'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String title;
  final String deadlineText;

  const _OrderCard({Key? key, required this.title, required this.deadlineText})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outline.withOpacity(0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: cs.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Дедлайн: $deadlineText',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
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

class _EmptyOrdersState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyOrdersState({Key? key, required this.onCreate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'У вас пока нет заказов',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте первый заказ, чтобы исполнители могли откликаться на ваши задачи.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Создать заказ'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
