import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class AccountPage extends StatefulWidget {
  final String? userId;

  const AccountPage({Key? key, this.userId}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  String? _profileId;
  String? _profileCreated;
  String? _profileAvatarUrl;

  String? _drawerRole;
  String? _drawerName;
  String? _drawerAvatarUrl;

  List<Map<String, dynamic>> _feedbacks = [];
  double _avgRating = 0;
  int _totalFeedbacks = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
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

  String _roleLabel(String role) {
    switch (role) {
      case 'customer':
        return 'Заказчик';
      case 'support':
        return 'Поддержка';
      case 'executor':
        return 'Исполнитель';
      default:
        return 'Пользователь';
    }
  }

  String _feedbackTypeLabel(String? type) {
    switch (type) {
      case 'customer_to_executor':
        return 'Отзыв заказчика';
      case 'executor_to_customer':
        return 'Отзыв исполнителя';
      default:
        return 'Отзыв';
    }
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

  Future<void> _loadDrawerData(String currentUserId) async {
    final user = await PocketBaseService.instance.pb
        .collection('users')
        .getOne(currentUserId);

    _drawerRole = _roleFromUser(user.data);
    _drawerName =
        user.data['name'] as String? ?? user.data['email'] as String? ?? 'User';

    _drawerAvatarUrl = PocketBaseFileService.fileUrl(
      collectionName: 'users',
      recordId: user.id,
      fileValue: user.data['photo'],
    );
  }

  Future<void> _loadAccountData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final currentUserId = service.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      await _loadDrawerData(currentUserId);

      final id = widget.userId ?? currentUserId;
      final user = await pb.collection('users').getOne(id);

      _profileId = user.id;
      _profileCreated = user.get<String>('created') ?? '';
      _profile = Map<String, dynamic>.from(user.data);

      _profileAvatarUrl = PocketBaseFileService.fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      await _loadFeedbacks(id);
    } catch (e) {
      _error = 'Ошибка загрузки профиля: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadFeedbacks(String profileUserId) async {
    final pb = PocketBaseService.instance.pb;

    _feedbacks = [];
    _avgRating = 0;
    _totalFeedbacks = 0;

    final feedbacksResult = await pb
        .collection('feedbacks')
        .getList(page: 1, perPage: 200);

    final ordersResult = await pb
        .collection('orders')
        .getList(page: 1, perPage: 200);

    final ordersById = <String, Map<String, dynamic>>{};
    final legacyExecutorOrderIds = <String>{};

    for (final order in ordersResult.items) {
      final data = {
        'id': order.id,
        'created': order.get<String>('created') ?? '',
        ...order.data,
      };

      ordersById[order.id] = data;

      final executorId = _relationId(order.data['executor_id']);
      if (executorId == profileUserId) {
        legacyExecutorOrderIds.add(order.id);
      }
    }

    for (final feedback in feedbacksResult.items) {
      final reviewedUserId = _relationId(feedback.data['reviewed_user_id']);
      final orderId = _relationId(feedback.data['order_id']);

      final isNewFormat = reviewedUserId != null;
      final isForThisProfile = reviewedUserId == profileUserId;
      final isLegacyForExecutor =
          !isNewFormat && orderId != null && legacyExecutorOrderIds.contains(orderId);

      if (!isForThisProfile && !isLegacyForExecutor) continue;

      final order = orderId == null ? null : ordersById[orderId];

      String? reviewerId = _relationId(feedback.data['reviewer_id']);

      if (reviewerId == null && order != null) {
        reviewerId = _relationId(order['customer_id']);
      }

      final reviewer = await _getRecordData('users', reviewerId);

      final reviewerName =
          reviewer?['name'] as String? ??
          reviewer?['email'] as String? ??
          'Пользователь';

      final reviewerRole = reviewer == null
          ? 'Пользователь'
          : _roleLabel(_roleFromUser(reviewer));

      final orderTitle =
          order?['task_description'] as String? ?? 'Заказ без описания';

      final type = feedback.data['type']?.toString();

      _feedbacks.add({
        'id': feedback.id,
        'estimate': feedback.data['estimate'],
        'text': feedback.data['text'] as String? ?? '',
        'created': feedback.get<String>('created') ?? '',
        'reviewer_name': reviewerName,
        'reviewer_role': reviewerRole,
        'type_label': _feedbackTypeLabel(type),
        'order_title': orderTitle,
      });
    }

    _feedbacks.sort((a, b) {
      final da = DateTime.tryParse(a['created'] as String? ?? '');
      final db = DateTime.tryParse(b['created'] as String? ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    _totalFeedbacks = _feedbacks.length;

    if (_totalFeedbacks > 0) {
      _avgRating = _feedbacks
              .map((f) => (f['estimate'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a + b) /
          _totalFeedbacks;
    }
  }

  String _formatAge(String? birthRaw) {
    final birth = DateTime.tryParse(birthRaw ?? '');
    if (birth == null) return '—';

    final now = DateTime.now();
    var age = now.year - birth.year;

    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }

    return '$age лет';
  }

  String _formatDate(String? raw) {
    final dt = DateTime.tryParse(raw ?? '');
    if (dt == null) return '—';

    return _dateFmt.format(dt.toLocal());
  }

  String _nonEmptyOrDash(dynamic value) {
    if (value is! String) return '—';

    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  bool get _isSelf {
    final currentUserId = PocketBaseService.instance.currentUserId;
    return widget.userId == null || _profileId == currentUserId;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    final role = _drawerRole;

    if (role == 'customer') {
      context.go('/customer');
      return;
    }

    if (role == 'support') {
      context.go('/support');
      return;
    }

    context.go('/tasks');
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSelf ? 'Мой профиль' : 'Профиль';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: (_isSelf && _drawerRole != null && _drawerName != null)
          ? AppDrawer(
              role: _drawerRole!,
              displayName: _drawerName!,
              avatarUrl: _drawerAvatarUrl,
            )
          : null,
      body: AppScreenBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? AppErrorState(
                      message: _error!,
                      onRetry: _loadAccountData,
                    )
                  : Column(
                      children: [
                        AppTopBar(
                          title: title,
                          subtitle: _isSelf
                              ? 'Данные аккаунта, рейтинг и отзывы'
                              : 'Публичная карточка пользователя',
                          onMenu: _isSelf
                              ? () => _scaffoldKey.currentState?.openDrawer()
                              : null,
                          onBack: _isSelf ? null : _goBack,
                          onRefresh: _loadAccountData,
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadAccountData,
                            child: ListView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                              children: [
                                _ProfileHeroCard(
                                  profile: _profile!,
                                  avatarUrl: _profileAvatarUrl,
                                  avgRating: _avgRating,
                                  totalFeedbacks: _totalFeedbacks,
                                  ageText: _formatAge(
                                    _profile!['birth_date'] as String?,
                                  ),
                                  roleLabel: _roleLabel(
                                    _profile!['role'] as String? ?? 'executor',
                                  ),
                                  isSelf: _isSelf,
                                  onEdit: _isSelf
                                      ? () async {
                                          await context.push('/account/edit');
                                          await _loadAccountData();
                                        }
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                _ProfileStatsCard(
                                  avgRating: _avgRating,
                                  totalFeedbacks: _totalFeedbacks,
                                  roleLabel: _roleLabel(
                                    _profile!['role'] as String? ?? 'executor',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _ProfileInfoCard(
                                  description: _nonEmptyOrDash(
                                    _profile!['description'],
                                  ),
                                  birthDate: _formatDate(
                                    _profile!['birth_date'] as String?,
                                  ),
                                  createdAt: _formatDate(_profileCreated),
                                  email: _nonEmptyOrDash(_profile!['email']),
                                ),
                                const SizedBox(height: 12),
                                AppSectionHeader(
                                  title: 'Отзывы',
                                  count: _feedbacks.length,
                                ),
                                const SizedBox(height: 8),
                                if (_feedbacks.isEmpty)
                                  const AppEmptyState(
                                    icon: CupertinoIcons.star,
                                    title: 'Отзывов пока нет',
                                    subtitle:
                                        'Отзывы появятся после оплаченных заказов.',
                                  )
                                else
                                  ..._feedbacks.map(
                                    (feedback) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _FeedbackCard(
                                        estimate:
                                            (feedback['estimate'] as num?)
                                                    ?.toInt() ??
                                                0,
                                        text: feedback['text'] as String? ?? '',
                                        date: _formatDate(
                                          feedback['created'] as String?,
                                        ),
                                        reviewerName:
                                            feedback['reviewer_name']
                                                    as String? ??
                                                'Пользователь',
                                        reviewerRole:
                                            feedback['reviewer_role']
                                                    as String? ??
                                                'Пользователь',
                                        typeLabel:
                                            feedback['type_label'] as String? ??
                                                'Отзыв',
                                        orderTitle:
                                            feedback['order_title']
                                                    as String? ??
                                                'Заказ',
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
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String? avatarUrl;
  final double avgRating;
  final int totalFeedbacks;
  final String ageText;
  final String roleLabel;
  final bool isSelf;
  final VoidCallback? onEdit;

  const _ProfileHeroCard({
    required this.profile,
    required this.avatarUrl,
    required this.avgRating,
    required this.totalFeedbacks,
    required this.ageText,
    required this.roleLabel,
    required this.isSelf,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String? ?? 'Пользователь';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AppProfileAvatar(
            avatarUrl: avatarUrl,
            size: 82,
          ),
          const SizedBox(height: 12),
          Text(
            name.trim().isEmpty ? 'Пользователь' : name,
            style: AppTextStyles.pageTitle.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            ageText,
            style: AppTextStyles.small,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              AppStatusPill(
                text: roleLabel,
                color: AppColors.accent,
                icon: CupertinoIcons.person_crop_circle,
              ),
              AppStatusPill(
                text: totalFeedbacks == 0
                    ? 'нет отзывов'
                    : '${avgRating.toStringAsFixed(1)} / 5',
                color: AppColors.accent,
                icon: CupertinoIcons.star_fill,
              ),
            ],
          ),
          if (isSelf && onEdit != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Редактировать профиль'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileStatsCard extends StatelessWidget {
  final double avgRating;
  final int totalFeedbacks;
  final String roleLabel;

  const _ProfileStatsCard({
    required this.avgRating,
    required this.totalFeedbacks,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: CupertinoIcons.star_fill,
              label: 'Рейтинг',
              value: totalFeedbacks == 0 ? '—' : avgRating.toStringAsFixed(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              icon: CupertinoIcons.chat_bubble_text,
              label: 'Отзывы',
              value: totalFeedbacks.toString(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              icon: CupertinoIcons.person_crop_circle,
              label: 'Роль',
              value: roleLabel,
            ),
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

class _ProfileInfoCard extends StatelessWidget {
  final String description;
  final String birthDate;
  final String createdAt;
  final String email;

  const _ProfileInfoCard({
    required this.description,
    required this.birthDate,
    required this.createdAt,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Информация'),
          const SizedBox(height: 12),
          _InfoRow(
            icon: CupertinoIcons.mail,
            label: 'Email',
            value: email,
          ),
          _InfoRow(
            icon: CupertinoIcons.calendar,
            label: 'Дата рождения',
            value: birthDate,
          ),
          _InfoRow(
            icon: CupertinoIcons.clock,
            label: 'Дата регистрации',
            value: createdAt,
          ),
          _InfoRow(
            icon: CupertinoIcons.text_alignleft,
            label: 'Описание',
            value: description,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final int estimate;
  final String text;
  final String date;
  final String reviewerName;
  final String reviewerRole;
  final String typeLabel;
  final String orderTitle;

  const _FeedbackCard({
    required this.estimate,
    required this.text,
    required this.date,
    required this.reviewerName,
    required this.reviewerRole,
    required this.typeLabel,
    required this.orderTitle,
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
              const AppProfileAvatar(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$reviewerRole · $typeLabel',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(date, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < estimate
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 19,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              Text(
                '$estimate / 5',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text.trim().isEmpty ? 'Без текста' : text,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Text(
            orderTitle.trim().isEmpty ? 'Заказ без описания' : orderTitle,
            style: AppTextStyles.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: AppTextStyles.small),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.small.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
