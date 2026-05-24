// lib/pages/support_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({Key? key}) : super(key: key);

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _searchController = TextEditingController();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  String _sortOrder = 'Newest';

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _requests = [];

  String? _role;
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru') return 'customer';
    if (normalized == 'support@test.ru') return 'support';
    if (normalized == 'executor@test.ru') return 'executor';

    return 'executor';
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

      _role = _roleFromUser(user.data);
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';
      _photo = user.data['photo'] as String?;

      final requestResult = await pb
          .collection('support_requests')
          .getList(page: 1, perPage: 200);

      final result = <Map<String, dynamic>>[];

      for (final record in requestResult.items) {
        final requestUserId = _relationId(record.data['user_id']);

        if (_role != 'support' && requestUserId != userId) {
          continue;
        }

        result.add({
          'id': record.id,
          'reason': record.data['reason'] as String? ?? '',
          'created': record.created,
          'user_id': requestUserId,
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

      _requests = result;
    } catch (e) {
      _error = 'Не удалось загрузить обращения: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();

    var list =
        _requests.where((request) {
          final reason = (request['reason'] as String? ?? '').toLowerCase();
          return reason.contains(q);
        }).toList();

    if (_sortOrder == 'Oldest') {
      list = list.reversed.toList();
    }

    return list;
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';
    return _dateFmt.format(dt.toLocal());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final border = cs.onSurface.withOpacity(0.16);
    final filtered = _filtered;

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
              'Support',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: cs.surface,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Новое обращение'),
        onPressed: () async {
          final created = await context.push<bool>('/support/new');

          if (created == true) {
            await _loadAll();
          }
        },
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
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ),
                )
                : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chat_bubble_outline,
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Центр поддержки',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: cs.onSecondaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _role == 'support'
                                            ? 'Просматривайте все обращения пользователей.'
                                            : 'Следите за своими обращениями и продолжайте диалог с поддержкой.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: cs.onSecondaryContainer
                                                  .withOpacity(0.8),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Поиск обращений…',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _sortOrder,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Newest',
                                        child: Text('Newest'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Oldest',
                                        child: Text('Oldest'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _sortOrder = v);
                                      }
                                    },
                                    iconEnabledColor: cs.onSurface,
                                    style: theme.textTheme.bodyMedium?.copyWith(
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _role == 'support'
                                  ? 'Все обращения'
                                  : 'Мои обращения',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child:
                              filtered.isEmpty
                                  ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.inbox_outlined,
                                          size: 48,
                                          color: cs.onSurface.withOpacity(0.4),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Пока нет обращений',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(color: cs.onSurface),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Нажмите «Новое обращение», чтобы связаться с поддержкой.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.onSurface.withOpacity(
                                                  0.7,
                                                ),
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      88,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (ctx, i) {
                                      final request = filtered[i];
                                      final id = request['id'] as String;
                                      final reason =
                                          request['reason'] as String? ?? '';
                                      final date = _formatDate(
                                        request['created'] as String?,
                                      );

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          onTap:
                                              () =>
                                                  context.push('/support/$id'),
                                          child: Card(
                                            color: cs.secondaryContainer,
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              side: BorderSide(color: border),
                                            ),
                                            margin: EdgeInsets.zero,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: cs.primary
                                                          .withOpacity(0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .support_agent_rounded,
                                                      color: cs.primary,
                                                      size: 22,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          reason,
                                                          style: theme
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          'Создано: $date',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: cs
                                                                    .onSurface
                                                                    .withOpacity(
                                                                      0.75,
                                                                    ),
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: cs.onSurface
                                                        .withOpacity(0.5),
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
                ),
      ),
    );
  }
}
