// lib/pages/executor_invitations_page.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/application_decision_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class ExecutorInvitationsPage extends StatefulWidget {
  const ExecutorInvitationsPage({Key? key}) : super(key: key);

  @override
  State<ExecutorInvitationsPage> createState() =>
      _ExecutorInvitationsPageState();
}

class _ExecutorInvitationsPageState extends State<ExecutorInvitationsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _fmt = DateFormat('dd.MM.yyyy HH:mm');

  bool _loading = true;
  bool _silentRefreshing = false;
  bool _showProcessed = false;
  String? _error;
  String? _busyInviteId;

  Timer? _refreshDebounce;

  String? _role;
  String? _name;
  String? _photo;

  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();

    final pb = PocketBaseService.instance.pb;
    pb.collection('applications').unsubscribe('*');
    pb.collection('orders').unsubscribe('*');
    pb.collection('tasks').unsubscribe('*');
    pb.collection('users').unsubscribe('*');
    pb.collection('task_statuses').unsubscribe('*');
    pb.collection('payment_statuses').unsubscribe('*');

    _searchController.dispose();
    super.dispose();
  }

  Future<void> _subscribeRealtime() async {
    final pb = PocketBaseService.instance.pb;

    Future<void> onAnyChange(dynamic _) async {
      _scheduleSilentRefresh();
    }

    await pb.collection('applications').subscribe('*', onAnyChange);
    await pb.collection('orders').subscribe('*', onAnyChange);
    await pb.collection('tasks').subscribe('*', onAnyChange);
    await pb.collection('users').subscribe('*', onAnyChange);
    await pb.collection('task_statuses').subscribe('*', onAnyChange);
    await pb.collection('payment_statuses').subscribe('*', onAnyChange);
  }

  void _scheduleSilentRefresh() {
    _refreshDebounce?.cancel();

    _refreshDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted || _silentRefreshing) return;

      _silentRefreshing = true;
      try {
        await _loadAll(showLoader: false);
      } finally {
        _silentRefreshing = false;
      }
    });
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

  String _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' ||
        normalized == 'dev1@test.local' ||
        normalized == '1') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' ||
        normalized == 'dev3@test.local' ||
        normalized == '3') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' ||
        normalized == 'dev2@test.local' ||
        normalized == '2') {
      return 'executor';
    }

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

  String _status(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    if (raw == 'approved' || raw == 'rejected' || raw == 'pending') {
      return raw!;
    }

    return 'pending';
  }

  bool _isPending(Map<String, dynamic> item) {
    return _status(item['status']) == 'pending';
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
        'updated': record.get<String>('updated') ?? '',
        ...record.data,
      };
    } catch (_) {
      return null;
    }
  }

  Future<String?> _taskIdForOrder(String orderId) async {
    return ApplicationDecisionService.taskIdForOrder(orderId);
  }

  Future<void> _loadAll({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final currentUserId = service.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      final currentUser = await pb.collection('users').getOne(currentUserId);

      final role = _roleFromUser(currentUser.data);
      final name =
          currentUser.data['name'] as String? ??
          currentUser.data['email'] as String? ??
          'User';

      final photo = PocketBaseFileService.fileUrl(
        collectionName: 'users',
        recordId: currentUser.id,
        fileValue: currentUser.data['photo'],
      );

      final result = await pb
          .collection('applications')
          .getList(page: 1, perPage: 200);

      final loaded = <Map<String, dynamic>>[];

      for (final app in result.items) {
        final source = app.data['source']?.toString().trim().toLowerCase();
        final executorId = _relationId(app.data['executor_id']);

        if (source != 'customer_invite') continue;
        if (executorId != currentUserId) continue;

        final orderId = _relationId(app.data['order_id']);
        final order = await _getRecordData('orders', orderId);

        if (order == null) continue;

        final customerId = _relationId(order['customer_id']);
        final customer = await _getRecordData('users', customerId);
        final taskId = orderId == null ? null : await _taskIdForOrder(orderId);

        final customerPhoto =
            customerId == null
                ? null
                : PocketBaseFileService.fileUrl(
                  collectionName: 'users',
                  recordId: customerId,
                  fileValue: customer?['photo'],
                );

        loaded.add({
          'id': app.id,
          'created': app.get<String>('created') ?? '',
          'updated': app.get<String>('updated') ?? '',
          'status': _status(app.data['status']),
          'message': app.data['message'] as String? ?? '',
          'order_id': orderId,
          'task_id': taskId,
          'order_title': order['task_description'] as String? ?? '',
          'order_price': order['price'],
          'order_deadline': order['deadline'],
          'customer_id': customerId,
          'customer_name':
              customer?['name'] as String? ??
              customer?['email'] as String? ??
              'Заказчик',
          'customer_photo': customerPhoto,
        });
      }

      loaded.sort((a, b) {
        final da = DateTime.tryParse(a['created'] as String? ?? '');
        final db = DateTime.tryParse(b['created'] as String? ?? '');

        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;

        return db.compareTo(da);
      });

      if (!mounted) return;

      setState(() {
        _role = role;
        _name = name;
        _photo = photo;
        _invitations = loaded;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить приглашения: $e';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _visibleInvitations {
    final query = _searchController.text.trim().toLowerCase();

    final filteredByStatus = _invitations.where((item) {
      final pending = _isPending(item);
      return _showProcessed ? !pending : pending;
    });

    if (query.isEmpty) return filteredByStatus.toList();

    return filteredByStatus.where((item) {
      final title = (item['order_title'] as String? ?? '').toLowerCase();
      final customer = (item['customer_name'] as String? ?? '').toLowerCase();
      final message = (item['message'] as String? ?? '').toLowerCase();

      return title.contains(query) ||
          customer.contains(query) ||
          message.contains(query);
    }).toList();
  }

  int get _pendingCount {
    return _invitations.where(_isPending).length;
  }

  int get _processedCount {
    return _invitations.where((item) => !_isPending(item)).length;
  }

  String _formatMoney(dynamic raw) {
    final value = (raw as num?) ?? 0;

    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ₽';
    }

    return '${value.toStringAsFixed(2)} ₽';
  }

  String _formatDateTime(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';

    return _fmt.format(dt.toLocal());
  }

  Future<void> _acceptInvitation(Map<String, dynamic> item) async {
    if (_busyInviteId != null) return;

    setState(() => _busyInviteId = item['id'] as String);

    try {
      final currentUserId = PocketBaseService.instance.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      final taskId = await ApplicationDecisionService.acceptApplication(
        applicationId: item['id'] as String,
        actorUserId: currentUserId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Приглашение принято')));

      await _loadAll(showLoader: false);

      if (!mounted) return;

      context.push('/tasks/details/$taskId');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка принятия: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyInviteId = null);
      }
    }
  }

  Future<void> _rejectInvitation(Map<String, dynamic> item) async {
    if (_busyInviteId != null) return;

    setState(() => _busyInviteId = item['id'] as String);

    try {
      final currentUserId = PocketBaseService.instance.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      await ApplicationDecisionService.rejectApplication(
        applicationId: item['id'] as String,
        actorUserId: currentUserId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Приглашение отклонено')));

      await _loadAll(showLoader: false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка отклонения: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyInviteId = null);
      }
    }
  }

  void _openOrder(Map<String, dynamic> item) {
    final orderId = item['order_id'] as String?;

    if (orderId == null || orderId.isEmpty) return;

    context.push('/orders/details/$orderId');
  }

  void _openTask(Map<String, dynamic> item) {
    final taskId = item['task_id'] as String?;

    if (taskId == null || taskId.isEmpty) return;

    context.push('/tasks/details/$taskId');
  }

  void _openCustomerProfile(Map<String, dynamic> item) {
    final customerId = item['customer_id'] as String?;

    if (customerId == null || customerId.isEmpty) return;

    context.push('/account/$customerId');
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleInvitations;
    final hasSearch = _searchController.text.trim().isNotEmpty;

    final emptyTitle =
        hasSearch
            ? 'Ничего не найдено'
            : _showProcessed
            ? 'Обработанных приглашений нет'
            : 'Новых приглашений нет';

    final emptySubtitle =
        hasSearch
            ? 'Измени поисковый запрос.'
            : _showProcessed
            ? 'Принятые и отклонённые приглашения появятся здесь.'
            : 'Когда заказчик пригласит вас на заказ, приглашение появится здесь.';

    return Scaffold(
      key: _scaffoldKey,
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadAll)
                  : Column(
                    children: [
                      AppTopBar(
                        title:
                            _showProcessed
                                ? 'История приглашений'
                                : 'Приглашения',
                        subtitle:
                            _showProcessed
                                ? 'Принятые и отклонённые приглашения'
                                : 'Входящие приглашения от заказчиков',
                        onMenu: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        onRefresh: _loadAll,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadAll,
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: _InvitationsOverviewCard(
                                    name: _name ?? 'Исполнитель',
                                    avatarUrl: _photo,
                                    pendingCount: _pendingCount,
                                    processedCount: _processedCount,
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: AppSearchField(
                                    controller: _searchController,
                                    hint:
                                        'Поиск по заказчику, заказу, сообщению',
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        AppFilterChip(
                                          icon: CupertinoIcons.mail,
                                          label: 'Новые $_pendingCount',
                                          active: !_showProcessed,
                                          onTap: () {
                                            setState(() {
                                              _showProcessed = false;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        AppFilterChip(
                                          icon: CupertinoIcons.archivebox,
                                          label: 'История $_processedCount',
                                          active: _showProcessed,
                                          onTap: () {
                                            setState(() {
                                              _showProcessed = true;
                                            });
                                          },
                                        ),
                                        if (hasSearch) ...[
                                          const SizedBox(width: 8),
                                          AppFilterChip(
                                            icon: CupertinoIcons.clear,
                                            label: 'Сбросить',
                                            danger: true,
                                            onTap: () {
                                              setState(() {
                                                _searchController.clear();
                                              });
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  16,
                                  12,
                                  8,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: AppSectionHeader(
                                    title:
                                        _showProcessed
                                            ? 'История'
                                            : 'Новые приглашения',
                                    count: items.length,
                                  ),
                                ),
                              ),
                              if (items.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AppEmptyState(
                                    icon:
                                        hasSearch
                                            ? CupertinoIcons.search
                                            : CupertinoIcons.mail,
                                    title: emptyTitle,
                                    subtitle: emptySubtitle,
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    20,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      if (index.isOdd) {
                                        return const SizedBox(height: 8);
                                      }

                                      final itemIndex = index ~/ 2;
                                      final item = items[itemIndex];
                                      final itemId = item['id'] as String;

                                      return _InvitationCard(
                                        item: item,
                                        busy: _busyInviteId == itemId,
                                        disabled: _busyInviteId != null,
                                        createdText: _formatDateTime(
                                          item['created'] as String?,
                                        ),
                                        priceText: _formatMoney(
                                          item['order_price'],
                                        ),
                                        onAccept: () => _acceptInvitation(item),
                                        onReject: () => _rejectInvitation(item),
                                        onOpenOrder: () => _openOrder(item),
                                        onOpenTask: () => _openTask(item),
                                        onOpenCustomer:
                                            () => _openCustomerProfile(item),
                                      );
                                    }, childCount: items.length * 2 - 1),
                                  ),
                                ),
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

class _InvitationsOverviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int pendingCount;
  final int processedCount;

  const _InvitationsOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.pendingCount,
    required this.processedCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppProfileAvatar(avatarUrl: avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.cardTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text('Исполнитель', style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'invites',
                color: AppColors.accent,
                icon: CupertinoIcons.mail,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Здесь отображаются приглашения от заказчиков. После принятия создаётся задача, а заказ закрепляется за вами.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: CupertinoIcons.mail,
                  label: 'Новые',
                  value: pendingCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: CupertinoIcons.archivebox,
                  label: 'История',
                  value: processedCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final bool disabled;
  final String createdText;
  final String priceText;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onOpenOrder;
  final VoidCallback onOpenTask;
  final VoidCallback onOpenCustomer;

  const _InvitationCard({
    required this.item,
    required this.busy,
    required this.disabled,
    required this.createdText,
    required this.priceText,
    required this.onAccept,
    required this.onReject,
    required this.onOpenOrder,
    required this.onOpenTask,
    required this.onOpenCustomer,
  });

  String get _status {
    return (item['status'] as String? ?? 'pending').trim().toLowerCase();
  }

  bool get _pending {
    return _status == 'pending';
  }

  bool get _approved {
    return _status == 'approved';
  }

  String get _statusText {
    if (_approved) return 'Принято';
    if (_status == 'rejected') return 'Отклонено';
    return 'Ожидает решения';
  }

  AppStatusPill get _statusPill {
    if (_approved) return AppStatusPill.success(_statusText);
    if (_status == 'rejected') return AppStatusPill.error(_statusText);
    return AppStatusPill.pending(_statusText);
  }

  @override
  Widget build(BuildContext context) {
    final title = item['order_title'] as String? ?? '';
    final message = item['message'] as String? ?? '';
    final customerName = item['customer_name'] as String? ?? 'Заказчик';
    final customerPhoto = item['customer_photo'] as String?;
    final taskId = item['task_id'] as String?;

    return AppSurfaceCard(
      onTap: onOpenOrder,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppProfileAvatar(avatarUrl: customerPhoto, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Заказчик · $createdText',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Профиль заказчика',
                onPressed: disabled ? null : onOpenCustomer,
                icon: const Icon(
                  CupertinoIcons.person_crop_circle,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title.trim().isEmpty ? 'Заказ без описания' : title,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(message, style: AppTextStyles.body),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusPill,
              AppTag(icon: Icons.currency_ruble_rounded, label: priceText),
              if (taskId != null && taskId.isNotEmpty)
                const AppTag(
                  icon: CupertinoIcons.doc_text,
                  label: 'Есть задача',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          if (_pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: disabled ? null : onAccept,
                    icon:
                        busy
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(CupertinoIcons.checkmark_alt_circle),
                    label: const Text('Принять'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: disabled ? null : onReject,
                    icon: const Icon(CupertinoIcons.xmark_circle),
                    label: const Text('Отклонить'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: disabled ? null : onOpenOrder,
                    icon: const Icon(CupertinoIcons.doc_text),
                    label: const Text('Открыть заказ'),
                  ),
                ),
                if (taskId != null && taskId.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: disabled ? null : onOpenTask,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Открыть задачу'),
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
