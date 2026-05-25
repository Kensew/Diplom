// lib/pages/support_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({Key? key}) : super(key: key);

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        'created': record.get<String>('created'),
        ...record.data,
      };
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

      _role = _roleFromUser(user.data);
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';

      _photo = _fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final requestResult = await pb
          .collection('support_requests')
          .getList(page: 1, perPage: 200);

      final result = <Map<String, dynamic>>[];

      for (final record in requestResult.items) {
        final requestUserId = _relationId(record.data['user_id']);

        if (_role != 'support' && requestUserId != userId) {
          continue;
        }

        final requestUser = await _getRecordData('users', requestUserId);

        final requestUserPhoto =
            requestUserId == null
                ? null
                : _fileUrl(
                  collectionName: 'users',
                  recordId: requestUserId,
                  fileValue: requestUser?['photo'],
                );

        result.add({
          'id': record.id,
          'reason': record.data['reason'] as String? ?? '',
          'created': record.get<String>('created'),
          'user_id': requestUserId,
          'user_name':
              requestUser?['name'] as String? ??
              requestUser?['email'] as String? ??
              'Пользователь',
          'user_photo': requestUserPhoto,
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
    final query = _searchController.text.trim().toLowerCase();

    var list =
        _requests.where((request) {
          final reason = (request['reason'] as String? ?? '').toLowerCase();
          final userName =
              (request['user_name'] as String? ?? '').toLowerCase();

          return reason.contains(query) || userName.contains(query);
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

  String _sortLabel(String value) {
    switch (value) {
      case 'Oldest':
        return 'Старые';
      case 'Newest':
      default:
        return 'Новые';
    }
  }

  Future<void> _selectSort() async {
    await showAppBottomSheet(
      context: context,
      title: 'Сортировка',
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          ...const ['Newest', 'Oldest'].map(
            (value) => AppBottomSheetOption(
              title: _sortLabel(value),
              selected: _sortOrder == value,
              onTap: () {
                Navigator.pop(context);
                setState(() => _sortOrder = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateRequest() async {
    final created = await context.push<bool>('/support/new');

    if (created == true) {
      await _loadAll();
    }
  }

  void _openRequest(String id) {
    context.push('/support/$id');
  }

  int get _myRequestsCount {
    final userId = PocketBaseService.instance.currentUserId;

    return _requests.where((request) {
      return request['user_id'] == userId;
    }).length;
  }

  int get _otherRequestsCount {
    final userId = PocketBaseService.instance.currentUserId;

    return _requests.where((request) {
      return request['user_id'] != userId;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final isSupport = _role == 'support';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRequest,
        icon: const Icon(Icons.add),
        label: const Text('Новое обращение'),
      ),
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
                        title: 'Поддержка',
                        subtitle:
                            isSupport
                                ? 'Все обращения пользователей'
                                : 'Ваши обращения в поддержку',
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
                                  child: _SupportOverviewCard(
                                    name: _name ?? 'Пользователь',
                                    avatarUrl: _photo,
                                    isSupport: isSupport,
                                    totalCount: _requests.length,
                                    myCount: _myRequestsCount,
                                    otherCount: _otherRequestsCount,
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
                                    hint: 'Поиск по обращениям',
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
                                          icon: CupertinoIcons.sort_down,
                                          label: _sortLabel(_sortOrder),
                                          active: true,
                                          onTap: _selectSort,
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
                                        isSupport
                                            ? 'Все обращения'
                                            : 'Мои обращения',
                                    count: filtered.length,
                                  ),
                                ),
                              ),
                              if (filtered.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: AppEmptyState(
                                    icon:
                                        hasSearch
                                            ? CupertinoIcons.search
                                            : CupertinoIcons.tray,
                                    title:
                                        hasSearch
                                            ? 'Ничего не найдено'
                                            : 'Обращений пока нет',
                                    subtitle:
                                        hasSearch
                                            ? 'Измени поисковый запрос.'
                                            : 'Создайте обращение, чтобы связаться с поддержкой.',
                                    action: ElevatedButton.icon(
                                      onPressed: _openCreateRequest,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Новое обращение'),
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    96,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      if (index.isOdd) {
                                        return const SizedBox(height: 8);
                                      }

                                      final requestIndex = index ~/ 2;
                                      final request = filtered[requestIndex];
                                      final id = request['id'] as String;

                                      return _SupportRequestCard(
                                        reason:
                                            request['reason'] as String? ?? '',
                                        createdAt: _formatDate(
                                          request['created'] as String?,
                                        ),
                                        userName:
                                            request['user_name'] as String? ??
                                            'Пользователь',
                                        userPhoto:
                                            request['user_photo'] as String?,
                                        showUser: isSupport,
                                        onTap: () => _openRequest(id),
                                      );
                                    }, childCount: filtered.length * 2 - 1),
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

class _SupportOverviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isSupport;
  final int totalCount;
  final int myCount;
  final int otherCount;

  const _SupportOverviewCard({
    required this.name,
    required this.avatarUrl,
    required this.isSupport,
    required this.totalCount,
    required this.myCount,
    required this.otherCount,
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
                    Text(
                      isSupport ? 'Сотрудник поддержки' : 'Пользователь',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'support',
                color: AppColors.accent,
                icon: Icons.support_agent_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isSupport
                ? 'Просматривайте обращения пользователей и продолжайте диалог в чате поддержки.'
                : 'Создавайте обращения и отслеживайте ответы поддержки.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.inbox_rounded,
                  label: 'Всего',
                  value: totalCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: CupertinoIcons.person_crop_circle,
                  label: 'Мои',
                  value: myCount.toString(),
                ),
              ),
              if (isSupport) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    icon: Icons.group_outlined,
                    label: 'Другие',
                    value: otherCount.toString(),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.cardTitle),
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

class _SupportRequestCard extends StatelessWidget {
  final String reason;
  final String createdAt;
  final String userName;
  final String? userPhoto;
  final bool showUser;
  final VoidCallback onTap;

  const _SupportRequestCard({
    required this.reason,
    required this.createdAt,
    required this.userName,
    required this.userPhoto,
    required this.showUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showUser) ...[
            Row(
              children: [
                AppProfileAvatar(avatarUrl: userPhoto, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    userName,
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(createdAt, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            reason.trim().isEmpty ? 'Без темы' : reason,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppMetaItem(
                  icon: CupertinoIcons.calendar_today,
                  label: 'Создано',
                  value: createdAt,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.arrow_right,
                  size: 17,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
