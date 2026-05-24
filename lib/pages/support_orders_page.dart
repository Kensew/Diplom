// lib/pages/support_orders_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class SupportOrdersPage extends StatefulWidget {
  const SupportOrdersPage({Key? key}) : super(key: key);

  @override
  State<SupportOrdersPage> createState() => _SupportOrdersPageState();
}

class _SupportOrdersPageState extends State<SupportOrdersPage> {
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  String _sort = 'Newest';
  bool _loading = true;
  String? _error;

  String? _role;
  String? _name;
  String? _photo;

  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Map<String, dynamic>? _expandData(dynamic record, String fieldName) {
    final items = record.expand[fieldName];

    if (items is List && items.isNotEmpty) {
      return items.first.data as Map<String, dynamic>;
    }

    return null;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDrawerData();
      await _loadOrders();
    } catch (e) {
      _error = 'Ошибка загрузки: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadDrawerData() async {
    final service = PocketBaseService.instance;
    final userId = service.currentUserId;

    if (userId == null) return;

    final user = await service.pb.collection('users').getOne(userId);

    _role = user.data['role'] as String? ?? 'support';
    _name =
        user.data['name'] as String? ??
        user.data['email'] as String? ??
        'Support';
    _photo = user.data['photo'] as String?;
  }

  Future<void> _loadOrders() async {
    final records = await PocketBaseService.instance.pb
        .collection('orders')
        .getFullList(sort: '-created', expand: 'framework_id,language_id');

    _orders =
        records.map((record) {
          final framework = _expandData(record, 'framework_id');
          final language = _expandData(record, 'language_id');

          return {
            'id': record.id,
            'created': record.created,
            'task_description':
                record.data['task_description'] as String? ?? '',
            'deadline': record.data['deadline'] as String?,
            'price': record.data['price'],
            'framework_name': framework?['name'] as String? ?? '—',
            'language_name': language?['name'] as String? ?? '—',
          };
        }).toList();
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Удалить заказ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Да'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    try {
      await PocketBaseService.instance.pb.collection('orders').delete(id);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
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

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();

    final list =
        _orders.where((order) {
          final desc =
              (order['task_description'] as String? ?? '').toLowerCase();
          return desc.contains(q);
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : const AppDrawer(role: 'support', displayName: 'Support'),
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text('All Orders'),
      ),
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search orders…',
                        filled: true,
                        fillColor: cs.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: cs.onSurface.withOpacity(0.3),
                          ),
                        ),
                        suffixIcon: Icon(Icons.search, color: cs.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: cs.onSurface.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sort,
                        items: const [
                          DropdownMenuItem(
                            value: 'Newest',
                            child: Text('Newest'),
                          ),
                          DropdownMenuItem(
                            value: 'Oldest',
                            child: Text('Oldest'),
                          ),
                          DropdownMenuItem(
                            value: 'By deadline',
                            child: Text('By deadline'),
                          ),
                          DropdownMenuItem(
                            value: 'Price ↑',
                            child: Text('Price ↑'),
                          ),
                          DropdownMenuItem(
                            value: 'Price ↓',
                            child: Text('Price ↓'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _sort = v);
                          }
                        },
                        iconEnabledColor: cs.onSurface,
                        style: TextStyle(color: cs.onSurface),
                        dropdownColor: cs.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
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
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      )
                      : RefreshIndicator(
                        onRefresh: _loadAll,
                        child:
                            filtered.isEmpty
                                ? ListView(
                                  children: const [
                                    SizedBox(height: 120),
                                    Center(child: Text('Заказов нет')),
                                  ],
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final order = filtered[i];

                                    final id = order['id'] as String;
                                    final desc =
                                        order['task_description'] as String? ??
                                        '';
                                    final price = _priceOf(order).toString();
                                    final fw =
                                        order['framework_name'] as String? ??
                                        '—';
                                    final lg =
                                        order['language_name'] as String? ??
                                        '—';

                                    return InkWell(
                                      onTap: () {
                                        context.push('/orders/details/$id');
                                      },
                                      child: Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        color: cs.secondary,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                desc,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: cs.onSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Framework: $fw',
                                                style: TextStyle(
                                                  color: cs.onSecondary,
                                                ),
                                              ),
                                              Text(
                                                'Language: $lg',
                                                style: TextStyle(
                                                  color: cs.onSecondary,
                                                ),
                                              ),
                                              Text(
                                                'Price: \$$price',
                                                style: TextStyle(
                                                  color: cs.onSecondary,
                                                ),
                                              ),
                                              Text(
                                                'Deadline: ${_formatDate(order['deadline'] as String?)}',
                                                style: TextStyle(
                                                  color: cs.onSecondary,
                                                ),
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomRight,
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  color: cs.error,
                                                  onPressed: () => _delete(id),
                                                ),
                                              ),
                                            ],
                                          ),
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
