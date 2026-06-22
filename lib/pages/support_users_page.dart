// lib/pages/support_users_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/support_moderation_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/utils/pocketbase_date.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class SupportUsersPage extends StatefulWidget {
  const SupportUsersPage({Key? key}) : super(key: key);

  @override
  State<SupportUsersPage> createState() => _SupportUsersPageState();
}

class _SupportUsersPageState extends State<SupportUsersPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  String _sort = 'Name';
  String _roleFilter = 'all';
  bool _loading = true;
  String? _error;

  String? _drawerRole;
  String? _drawerName;
  String? _drawerPhoto;

  List<Map<String, dynamic>> _users = [];

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

  String _roleLabel(String? role) {
    switch (role) {
      case 'customer':
        return 'Заказчик';
      case 'executor':
        return 'Исполнитель';
      case 'support':
        return 'Поддержка';
      default:
        return 'Пользователь';
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDrawerData();

      final records = await PocketBaseService.instance.pb
          .collection('users')
          .getFullList(sort: '-id');

      final bans = await SupportModerationService.instance.loadActiveBans();

      _users =
          records.map((record) {
            final role = PocketBaseService.resolveRole(record);
            final ban = bans[record.id];

            return {
              'id': record.id,
              'name': record.data['name'] as String? ?? '',
              'email': record.data['email'] as String? ?? '',
              'role': role,
              'description': record.data['description'] as String? ?? '',
              'is_banned': ban != null,
              'ban_reason': ban?.data['reason'] as String? ?? '',
              'banned_at': ban?.data['banned_at'] as String?,
              'created': record.created,
              'avatar_url': PocketBaseFileService.fileUrl(
                collectionName: 'users',
                recordId: record.id,
                fileValue: record.data['photo'],
              ),
            };
          }).toList();
    } catch (e) {
      _error = 'Ошибка загрузки пользователей: $e';
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

    _drawerRole = user.data['role'] as String? ?? 'support';
    _drawerName =
        user.data['name'] as String? ??
        user.data['email'] as String? ??
        'Support';
    _drawerPhoto = PocketBaseFileService.fileUrl(
      collectionName: 'users',
      recordId: user.id,
      fileValue: user.data['photo'],
    );
  }

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.trim().toLowerCase();

    var list =
        _users.where((user) {
          if (_roleFilter == 'banned' && user['is_banned'] != true) {
            return false;
          }

          if (_roleFilter != 'all' &&
              _roleFilter != 'banned' &&
              user['role'] != _roleFilter) {
            return false;
          }

          final name = (user['name'] as String? ?? '').toLowerCase();
          final email = (user['email'] as String? ?? '').toLowerCase();
          final role = _roleLabel(user['role'] as String?).toLowerCase();

          return name.contains(query) ||
              email.contains(query) ||
              role.contains(query);
        }).toList();

    switch (_sort) {
      case 'Role':
        list.sort((a, b) {
          final roleCompare = _roleLabel(
            a['role'] as String?,
          ).compareTo(_roleLabel(b['role'] as String?));
          if (roleCompare != 0) return roleCompare;
          return ((a['name'] as String?) ?? '').compareTo(
            (b['name'] as String?) ?? '',
          );
        });
        break;
      case 'Banned':
        list.sort((a, b) {
          final bannedA = a['is_banned'] == true ? 1 : 0;
          final bannedB = b['is_banned'] == true ? 1 : 0;
          if (bannedA != bannedB) return bannedB.compareTo(bannedA);
          return PocketBaseDate.compareDescWithId(
            createdA: a['created'] as String?,
            createdB: b['created'] as String?,
            idA: a['id'] as String?,
            idB: b['id'] as String?,
          );
        });
        break;
      case 'Newest':
        list.sort(
          (a, b) => PocketBaseDate.compareDescWithId(
            createdA: a['created'] as String?,
            createdB: b['created'] as String?,
            idA: a['id'] as String?,
            idB: b['id'] as String?,
          ),
        );
        break;
      case 'Name':
      default:
        list.sort((a, b) {
          final nameA = (a['name'] as String? ?? a['email'] as String? ?? '')
              .toLowerCase();
          final nameB = (b['name'] as String? ?? b['email'] as String? ?? '')
              .toLowerCase();
          return nameA.compareTo(nameB);
        });
    }

    return list;
  }

  int get _bannedCount => _users.where((user) => user['is_banned'] == true).length;

  String _sortLabel(String value) {
    switch (value) {
      case 'Role':
        return 'По роли';
      case 'Banned':
        return 'Заблокированные';
      case 'Newest':
        return 'Новые';
      case 'Name':
      default:
        return 'По имени';
    }
  }

  Future<void> _selectSort() async {
    await showAppBottomSheet(
      context: context,
      title: 'Сортировка',
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children:
            ['Name', 'Role', 'Banned', 'Newest']
                .map(
                  (value) => AppBottomSheetOption(
                    title: _sortLabel(value),
                    selected: _sort == value,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _sort = value);
                    },
                  ),
                )
                .toList(),
      ),
    );
  }

  Future<void> _confirmBan(Map<String, dynamic> user) async {
    if (user['role'] == 'support') {
      _showSnack('Нельзя заблокировать аккаунт поддержки');
      return;
    }

    final reasonController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Заблокировать ${user['name']}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Пользователь не сможет войти в систему. Укажите причину блокировки.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Причина',
                    hintText: 'Например: непристойные отзывы',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Заблокировать'),
              ),
            ],
          ),
    );

    if (ok != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    if (reason.isEmpty) {
      _showSnack('Укажите причину блокировки');
      return;
    }

    setState(() => _loading = true);

    try {
      await SupportModerationService.instance.banUser(
        userId: user['id'] as String,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((item) => item['id'] == user['id']);
        if (index >= 0) {
          _users[index] = {
            ..._users[index],
            'is_banned': true,
            'ban_reason': reason,
            'banned_at': DateTime.now().toUtc().toIso8601String(),
          };
        }
      });
      await _loadAll();
      if (!mounted) return;
      _showSnack('Пользователь заблокирован');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка блокировки: $e');
    }
  }

  Future<void> _confirmUnban(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Разблокировать ${user['name']}?'),
            content: const Text(
              'Пользователь снова сможет войти в систему.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Разблокировать'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      await SupportModerationService.instance.unbanUser(user['id'] as String);
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((item) => item['id'] == user['id']);
        if (index >= 0) {
          _users[index] = {
            ..._users[index],
            'is_banned': false,
            'ban_reason': '',
            'banned_at': null,
          };
        }
      });
      await _loadAll();
      if (!mounted) return;
      _showSnack('Пользователь разблокирован');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка разблокировки: $e');
    }
  }

  Future<void> _openUserModeration(Map<String, dynamic> user) async {
    final feedbacks = await SupportModerationService.instance.loadUserFeedbacks(
      user['id'] as String,
    );

    if (!mounted) return;

    await showAppBottomSheet(
      context: context,
      title: user['name'] as String? ?? user['email'] as String? ?? 'Пользователь',
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          Row(
            children: [
              AppProfileAvatar(
                avatarUrl: user['avatar_url'] as String?,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['email'] as String? ?? '',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleLabel(user['role'] as String?),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (user['is_banned'] == true) ...[
            const SizedBox(height: 12),
            AppStatusPill(
              text: 'Заблокирован',
              color: AppColors.danger,
              icon: Icons.block_rounded,
            ),
            if ((user['ban_reason'] as String? ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                user['ban_reason'] as String,
                style: AppTextStyles.body,
              ),
            ],
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/account/${user['id']}');
                  },
                  icon: const Icon(CupertinoIcons.person_crop_circle, size: 18),
                  label: const Text('Профиль'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      user['is_banned'] == true
                          ? () async {
                            Navigator.pop(context);
                            await _confirmUnban(user);
                          }
                          : user['role'] == 'support'
                          ? null
                          : () async {
                            Navigator.pop(context);
                            await _confirmBan(user);
                          },
                  icon: Icon(
                    user['is_banned'] == true
                        ? Icons.lock_open_rounded
                        : Icons.block_rounded,
                    size: 18,
                  ),
                  label: Text(
                    user['is_banned'] == true ? 'Разблокировать' : 'Заблокировать',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppSectionHeader(
            title: 'Отзывы пользователя',
            count: feedbacks.length,
          ),
          const SizedBox(height: 8),
          if (feedbacks.isEmpty)
            const AppEmptyState(
              icon: CupertinoIcons.star,
              title: 'Отзывов нет',
              subtitle: 'У пользователя пока нет связанных отзывов.',
            )
          else
            ...feedbacks.map((feedback) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SupportFeedbackTile(
                  estimate: (feedback['estimate'] as num?)?.toInt() ?? 0,
                  text: feedback['text'] as String? ?? '',
                  orderTitle: feedback['order_title'] as String? ?? '',
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: const Text('Удалить отзыв?'),
                            content: const Text(
                              'Отзыв будет удалён без возможности восстановления.',
                            ),
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

                    try {
                      await SupportModerationService.instance.deleteFeedback(
                        feedback['id'] as String,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await _openUserModeration(user);
                      await _loadAll();
                      _showSnack('Отзыв удалён');
                    } catch (e) {
                      _showSnack('Ошибка удаления: $e');
                    }
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer:
          (_drawerRole != null && _drawerName != null)
              ? AppDrawer(
                role: _drawerRole!,
                displayName: _drawerName!,
                avatarUrl: _drawerPhoto,
              )
              : const AppDrawer(role: 'support', displayName: 'Support'),
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
                        title: 'Пользователи',
                        subtitle: 'Модерация и блокировки',
                        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
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
                                  child: AppSurfaceCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Управление пользователями платформы: поиск, блокировка за нарушения, удаление непристойных отзывов.',
                                          style: AppTextStyles.body,
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _StatTile(
                                                icon: Icons.people_outline,
                                                label: 'Всего',
                                                value: _users.length.toString(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _StatTile(
                                                icon: Icons.block_rounded,
                                                label: 'Заблок.',
                                                value: _bannedCount.toString(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
                                    hint: 'Поиск по имени, email или роли',
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
                                          label: _sortLabel(_sort),
                                          active: true,
                                          onTap: _selectSort,
                                        ),
                                        const SizedBox(width: 8),
                                        AppFilterChip(
                                          icon: Icons.group_outlined,
                                          label: 'Все',
                                          active: _roleFilter == 'all',
                                          onTap:
                                              () => setState(
                                                () => _roleFilter = 'all',
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppFilterChip(
                                          icon: CupertinoIcons.person,
                                          label: 'Заказчики',
                                          active: _roleFilter == 'customer',
                                          onTap:
                                              () => setState(
                                                () => _roleFilter = 'customer',
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppFilterChip(
                                          icon: Icons.engineering_outlined,
                                          label: 'Исполнители',
                                          active: _roleFilter == 'executor',
                                          onTap:
                                              () => setState(
                                                () => _roleFilter = 'executor',
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppFilterChip(
                                          icon: Icons.block_rounded,
                                          label: 'Заблокированные',
                                          active: _roleFilter == 'banned',
                                          danger: _roleFilter == 'banned',
                                          onTap:
                                              () => setState(
                                                () => _roleFilter = 'banned',
                                              ),
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
                                    title: 'Список',
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
                                            : CupertinoIcons.person_2,
                                    title:
                                        hasSearch
                                            ? 'Ничего не найдено'
                                            : 'Пользователей нет',
                                    subtitle:
                                        hasSearch
                                            ? 'Измени поисковый запрос.'
                                            : 'Зарегистрированные пользователи появятся здесь.',
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

                                      final user = filtered[index ~/ 2];
                                      return _SupportUserCard(
                                        name:
                                            user['name'] as String? ??
                                            user['email'] as String? ??
                                            'Пользователь',
                                        email: user['email'] as String? ?? '',
                                        roleLabel: _roleLabel(
                                          user['role'] as String?,
                                        ),
                                        avatarUrl: user['avatar_url'] as String?,
                                        isBanned: user['is_banned'] == true,
                                        onTap: () => _openUserModeration(user),
                                        onBan:
                                            user['is_banned'] == true
                                                ? () => _confirmUnban(user)
                                                : () => _confirmBan(user),
                                        banLabel:
                                            user['is_banned'] == true
                                                ? 'Разблок.'
                                                : 'Блок',
                                        banDisabled: user['role'] == 'support',
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
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _SupportUserCard extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final String? avatarUrl;
  final bool isBanned;
  final VoidCallback onTap;
  final VoidCallback onBan;
  final String banLabel;
  final bool banDisabled;

  const _SupportUserCard({
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.avatarUrl,
    required this.isBanned,
    required this.onTap,
    required this.onBan,
    required this.banLabel,
    required this.banDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppTag(icon: CupertinoIcons.person, label: roleLabel),
                    if (isBanned)
                      const AppStatusPill(
                        text: 'Заблокирован',
                        color: AppColors.danger,
                        icon: Icons.block_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 34,
            onPressed: banDisabled ? null : onBan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isBanned
                        ? AppColors.accentSoft
                        : AppColors.danger.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                banLabel,
                style: AppTextStyles.caption.copyWith(
                  color: isBanned ? AppColors.accent : AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportFeedbackTile extends StatelessWidget {
  final int estimate;
  final String text;
  final String orderTitle;
  final VoidCallback onDelete;

  const _SupportFeedbackTile({
    required this.estimate,
    required this.text,
    required this.orderTitle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$estimate / 5',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 30,
                onPressed: onDelete,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text.trim().isEmpty ? 'Без текста' : text,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 8),
          Text('Заказ: $orderTitle', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
