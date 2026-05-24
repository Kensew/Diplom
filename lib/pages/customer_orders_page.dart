// lib/pages/customer_orders_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({Key? key}) : super(key: key);

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  String? _error;

  String _sort = 'Newest';
  String? _filterFramework;
  String? _filterLanguage;

  String? _role;
  String? _name;
  String? _photo;

  List<Map<String, dynamic>> _orders = [];
  List<String> _frameworks = [];
  List<String> _languages = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
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

  Future<Map<String, dynamic>?> _getRecordData(
    String collection,
    String? id,
  ) async {
    if (id == null || id.isEmpty) return null;

    try {
      final record = await PocketBaseService.instance.pb
          .collection(collection)
          .getOne(id);

      return {'id': record.id, 'created': record.created, ...record.data};
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAll() async {
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

      _role = user.data['role'] as String? ?? 'customer';
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';
      _photo = user.data['photo'] as String?;

      final ordersResult = await pb
          .collection('orders')
          .getList(page: 1, perPage: 200);

      final result = <Map<String, dynamic>>[];
      final fwSet = <String>{};
      final lgSet = <String>{};

      for (final record in ordersResult.items) {
        final customerId = _relationId(record.data['customer_id']);

        if (customerId != userId) continue;

        final frameworkId = _relationId(record.data['framework_id']);
        final languageId = _relationId(record.data['language_id']);
        final executorId = _relationId(record.data['executor_id']);

        final framework = await _getRecordData('frameworks', frameworkId);
        final language = await _getRecordData('languages', languageId);

        final frameworkName = framework?['name'] as String? ?? '—';
        final languageName = language?['name'] as String? ?? '—';

        if (frameworkName != '—') fwSet.add(frameworkName);
        if (languageName != '—') lgSet.add(languageName);

        result.add({
          'id': record.id,
          'created': record.created,
          'task_description': record.data['task_description'] as String? ?? '',
          'deadline': record.data['deadline'] as String?,
          'executor_id': executorId,
          'price': record.data['price'],
          'framework_name': frameworkName,
          'language_name': languageName,
        });
      }

      result.sort((a, b) {
        final da = DateTime.tryParse(a['created'] as String? ?? '');
        final db = DateTime.tryParse(b['created'] as String? ?? '');

        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;

        return db.compareTo(da);
      });

      _orders = result;
      _frameworks = fwSet.toList()..sort();
      _languages = lgSet.toList()..sort();
    } catch (e) {
      _error = 'Не удалось загрузить заказы: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Удалить заказ?'),
            content: const Text('Заказ будет удалён.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);

    try {
      await PocketBaseService.instance.pb.collection('orders').delete(orderId);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
    }
  }

  DateTime? _parseDate(String? raw) {
    return DateTime.tryParse(raw ?? '');
  }

  String _formatDate(String? raw) {
    final dt = _parseDate(raw);
    if (dt == null) return '—';
    return _fmt.format(dt.toLocal());
  }

  num _priceOf(Map<String, dynamic> order) {
    return (order['price'] as num?) ?? 0;
  }

  bool _hasExecutor(Map<String, dynamic> order) {
    return order['executor_id'] != null;
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final q = _searchController.text.trim().toLowerCase();

    final list =
        _orders.where((order) {
          final desc =
              (order['task_description'] as String? ?? '').toLowerCase();
          final fw = order['framework_name'] as String? ?? '';
          final lg = order['language_name'] as String? ?? '';

          return desc.contains(q) &&
              (_filterFramework == null || fw == _filterFramework) &&
              (_filterLanguage == null || lg == _filterLanguage);
        }).toList();

    switch (_sort) {
      case 'Oldest':
        return list.reversed.toList();

      case 'By deadline':
        list.sort((a, b) {
          final da = _parseDate(a['deadline'] as String?);
          final db = _parseDate(b['deadline'] as String?);

          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;

          return da.compareTo(db);
        });
        return list;

      case 'Price ↑':
        list.sort((a, b) => _priceOf(a).compareTo(_priceOf(b)));
        return list;

      case 'Price ↓':
        list.sort((a, b) => _priceOf(b).compareTo(_priceOf(a)));
        return list;

      case 'Newest':
      default:
        return list;
    }
  }

  void _clearFilters() {
    setState(() {
      _filterFramework = null;
      _filterLanguage = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filteredOrders = _filteredOrders;

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.assignment_turned_in_outlined, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Мои заказы',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/customer/create');
          await _loadAll();
        },
        icon: const Icon(Icons.add),
        label: const Text('Новый заказ'),
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
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Поиск по описанию…',
                                filled: true,
                                fillColor: cs.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                suffixIcon: Icon(
                                  Icons.search,
                                  color: cs.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _sort,
                            dropdownColor: cs.surface,
                            items: const [
                              DropdownMenuItem(
                                value: 'Newest',
                                child: Text('Новые'),
                              ),
                              DropdownMenuItem(
                                value: 'Oldest',
                                child: Text('Старые'),
                              ),
                              DropdownMenuItem(
                                value: 'By deadline',
                                child: Text('Дедлайн'),
                              ),
                              DropdownMenuItem(
                                value: 'Price ↑',
                                child: Text('Цена ↑'),
                              ),
                              DropdownMenuItem(
                                value: 'Price ↓',
                                child: Text('Цена ↓'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _sort = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DropdownChip(
                            label: 'Фреймворк',
                            value: _filterFramework,
                            values: _frameworks,
                            onChanged: (v) {
                              setState(() => _filterFramework = v);
                            },
                          ),
                          _DropdownChip(
                            label: 'Язык',
                            value: _filterLanguage,
                            values: _languages,
                            onChanged: (v) {
                              setState(() => _filterLanguage = v);
                            },
                          ),
                          ActionChip(
                            label: const Text('Сбросить'),
                            onPressed: _clearFilters,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          filteredOrders.isEmpty
                              ? Center(
                                child: Text(
                                  'Заказов не найдено',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              )
                              : RefreshIndicator(
                                onRefresh: _loadAll,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    90,
                                  ),
                                  itemCount: filteredOrders.length,
                                  itemBuilder: (_, i) {
                                    final order = filteredOrders[i];

                                    final id = order['id'] as String;
                                    final desc =
                                        order['task_description'] as String? ??
                                        '';
                                    final fw =
                                        order['framework_name'] as String? ??
                                        '—';
                                    final lg =
                                        order['language_name'] as String? ??
                                        '—';
                                    final price = _priceOf(order);
                                    final hasExec = _hasExecutor(order);

                                    return Card(
                                      elevation: 2,
                                      color: cs.surface,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    desc,
                                                    style: tt.titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  color: cs.error,
                                                  onPressed:
                                                      () => _deleteOrder(id),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Фреймворк: $fw'),
                                            Text('Язык: $lg'),
                                            Text(
                                              'Цена: \$${price.toStringAsFixed(0)}',
                                            ),
                                            Text(
                                              'Дедлайн: ${_formatDate(order['deadline'] as String?)}',
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              hasExec
                                                  ? 'Исполнитель назначен'
                                                  : 'Исполнитель не назначен',
                                              style: TextStyle(
                                                color:
                                                    hasExec
                                                        ? Colors.green
                                                        : cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _DropdownChip extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  const _DropdownChip({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: value,
      hint: Text(label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Все')),
        ...values.map(
          (v) => DropdownMenuItem<String?>(value: v, child: Text(v)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
