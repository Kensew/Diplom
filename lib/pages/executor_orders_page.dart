// lib/pages/executor_orders_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class ExecutorOrdersPage extends StatefulWidget {
  const ExecutorOrdersPage({Key? key}) : super(key: key);

  @override
  State<ExecutorOrdersPage> createState() => _ExecutorOrdersPageState();
}

class _ExecutorOrdersPageState extends State<ExecutorOrdersPage> {
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy');

  String _sort = 'Newest';
  String? _filterFramework;
  String? _filterLanguage;
  String? _filterDeadline;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _orders = [];
  List<String> _frameworks = [];
  List<String> _languages = [];

  String? _role;
  String? _name;
  String? _photo;

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

      _role = user.data['role'] as String? ?? 'executor';
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';
      _photo = user.data['photo'] as String?;

      final orderResult = await pb
          .collection('orders')
          .getList(page: 1, perPage: 200);

      final result = <Map<String, dynamic>>[];

      for (final record in orderResult.items) {
        final executorId = _relationId(record.data['executor_id']);

        if (executorId != null) continue;

        final frameworkId = _relationId(record.data['framework_id']);
        final languageId = _relationId(record.data['language_id']);

        final framework = await _getRecordData('frameworks', frameworkId);
        final language = await _getRecordData('languages', languageId);

        result.add({
          'id': record.id,
          'created': record.created,
          'task_description': record.data['task_description'] as String? ?? '',
          'deadline': record.data['deadline'] as String?,
          'price': record.data['price'],
          'framework_name': framework?['name'] as String? ?? '—',
          'language_name': language?['name'] as String? ?? '—',
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

      final fwResult = await pb
          .collection('frameworks')
          .getList(page: 1, perPage: 200);

      _frameworks =
          fwResult.items
              .map((record) => record.data['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList()
            ..sort();

      final lgResult = await pb
          .collection('languages')
          .getList(page: 1, perPage: 200);

      _languages =
          lgResult.items
              .map((record) => record.data['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList()
            ..sort();
    } catch (e) {
      _error = 'Не удалось загрузить данные: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickFilterDeadline(ColorScheme cs) async {
    final now = DateTime.now();
    DateTime initial = now;

    if (_filterDeadline != null) {
      try {
        initial = _fmt.parse(_filterDeadline!);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      builder:
          (_, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: cs.secondary,
                onPrimary: cs.onSecondary,
                surface: cs.surface,
                onSurface: cs.onSurface,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() => _filterDeadline = _fmt.format(picked));
    }
  }

  void _clearFilters() {
    setState(() {
      _filterFramework = null;
      _filterLanguage = null;
      _filterDeadline = null;
    });
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

  List<Map<String, dynamic>> get _filteredOrders {
    final q = _searchController.text.trim().toLowerCase();

    final list =
        _orders.where((order) {
          final desc =
              (order['task_description'] as String? ?? '').toLowerCase();
          final fw = order['framework_name'] as String? ?? '';
          final lg = order['language_name'] as String? ?? '';
          final dl = _formatDate(order['deadline'] as String?);

          return desc.contains(q) &&
              (_filterFramework == null || fw == _filterFramework) &&
              (_filterLanguage == null || lg == _filterLanguage) &&
              (_filterDeadline == null || dl == _filterDeadline);
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
    final tt = Theme.of(context).textTheme;
    final borderColor = Colors.white12;
    final filteredOrders = _filteredOrders;

    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.list_alt_outlined, color: cs.onSurface),
            const SizedBox(width: 8),
            Text(
              'Available Orders',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      backgroundColor: cs.background,
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
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                )
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(color: cs.onSurface),
                              decoration: InputDecoration(
                                hintText: 'Search orders…',
                                hintStyle: TextStyle(
                                  color: cs.onSurface.withOpacity(0.6),
                                ),
                                filled: true,
                                fillColor: cs.surfaceVariant,
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: cs.onSurface,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cs.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
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
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurface,
                                ),
                                dropdownColor: cs.surfaceVariant,
                              ),
                            ),
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
                          _buildDropdownChip(
                            cs,
                            'Framework',
                            _frameworks,
                            _filterFramework,
                            (v) => setState(() => _filterFramework = v),
                          ),
                          _buildDropdownChip(
                            cs,
                            'Language',
                            _languages,
                            _filterLanguage,
                            (v) => setState(() => _filterLanguage = v),
                          ),
                          _buildDeadlineChip(cs),
                          _buildClearChip(cs),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          filteredOrders.isEmpty
                              ? Center(
                                child: Text(
                                  'No orders found',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface.withOpacity(0.8),
                                  ),
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredOrders.length,
                                itemBuilder: (ctx, i) {
                                  final order = filteredOrders[i];

                                  final id = order['id'] as String;
                                  final desc =
                                      order['task_description'] as String? ??
                                      '';
                                  final fw =
                                      order['framework_name'] as String? ?? '—';
                                  final lg =
                                      order['language_name'] as String? ?? '—';
                                  final price = _priceOf(order);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () {
                                        context.push('/orders/details/$id');
                                      },
                                      child: Card(
                                        color: cs.secondaryContainer,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          side: BorderSide(color: borderColor),
                                        ),
                                        elevation: 0,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                desc,
                                                style: tt.titleMedium?.copyWith(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.developer_mode,
                                                    size: 16,
                                                    color: cs.onSurface
                                                        .withOpacity(0.7),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    fw,
                                                    style: tt.bodySmall
                                                        ?.copyWith(
                                                          color: cs.onSurface
                                                              .withOpacity(0.8),
                                                        ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Icon(
                                                    Icons.code,
                                                    size: 16,
                                                    color: cs.onSurface
                                                        .withOpacity(0.7),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    lg,
                                                    style: tt.bodySmall
                                                        ?.copyWith(
                                                          color: cs.onSurface
                                                              .withOpacity(0.8),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.attach_money,
                                                    size: 18,
                                                    color: cs.onSurface
                                                        .withOpacity(0.8),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    price.toString(),
                                                    style: tt.bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  const Spacer(),
                                                  Icon(
                                                    Icons.event,
                                                    size: 16,
                                                    color: cs.onSurface
                                                        .withOpacity(0.7),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatDate(
                                                      order['deadline']
                                                          as String?,
                                                    ),
                                                    style: tt.bodySmall
                                                        ?.copyWith(
                                                          color: cs.onSurface
                                                              .withOpacity(0.8),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildDropdownChip(
    ColorScheme cs,
    String label,
    List<String> opts,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: Text(
            label,
            style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
          ),
          value: value,
          items:
              opts
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: TextStyle(color: cs.onSurface)),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
          iconEnabledColor: cs.onSurface,
          dropdownColor: cs.surfaceVariant,
        ),
      ),
    );
  }

  Widget _buildDeadlineChip(ColorScheme cs) {
    return GestureDetector(
      onTap: () => _pickFilterDeadline(cs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: cs.onSurface.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Text(
              _filterDeadline ?? 'Deadline',
              style: TextStyle(color: cs.onSurface.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearChip(ColorScheme cs) {
    return InkWell(
      onTap: _clearFilters,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.error),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear, size: 16, color: cs.error),
            const SizedBox(width: 4),
            Text('Clear', style: TextStyle(color: cs.error)),
          ],
        ),
      ),
    );
  }
}
