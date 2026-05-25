// lib/pages/account_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

  Future<void> _loadDrawerData(String currentUserId) async {
    final user = await PocketBaseService.instance.pb
        .collection('users')
        .getOne(currentUserId);

    _drawerRole = _roleFromUser(user.data);
    _drawerName =
        user.data['name'] as String? ?? user.data['email'] as String? ?? 'User';

    _drawerAvatarUrl = _fileUrl(
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

      _profileAvatarUrl = _fileUrl(
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

    final ordersResult = await pb
        .collection('orders')
        .getList(page: 1, perPage: 200);

    final executorOrderIds = <String>{};

    for (final order in ordersResult.items) {
      final executorId = _relationId(order.data['executor_id']);

      if (executorId == profileUserId) {
        executorOrderIds.add(order.id);
      }
    }

    if (executorOrderIds.isEmpty) return;

    final feedbacksResult = await pb
        .collection('feedbacks')
        .getList(page: 1, perPage: 200);

    for (final feedback in feedbacksResult.items) {
      final orderId = _relationId(feedback.data['order_id']);

      if (orderId == null || !executorOrderIds.contains(orderId)) {
        continue;
      }

      _feedbacks.add({
        'id': feedback.id,
        'estimate': feedback.data['estimate'],
        'text': feedback.data['text'] as String? ?? '',
        'created': feedback.get<String>('created') ?? '',
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
      _avgRating =
          _feedbacks
              .map((f) => (f['estimate'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a + b) /
          _totalFeedbacks;
    }
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
      drawer:
          (_isSelf && _drawerRole != null && _drawerName != null)
              ? AppDrawer(
                role: _drawerRole!,
                displayName: _drawerName!,
                avatarUrl: _drawerAvatarUrl,
              )
              : null,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadAccountData)
                  : Column(
                    children: [
                      AppTopBar(
                        title: title,
                        subtitle:
                            _isSelf
                                ? 'Данные аккаунта и отзывы'
                                : 'Публичная карточка пользователя',
                        onMenu:
                            _isSelf
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
                              _ProfileMainCard(
                                profile: _profile!,
                                avatarUrl: _profileAvatarUrl,
                                createdAt: _profileCreated,
                                isSelf: _isSelf,
                                ageText: _formatAge(
                                  _profile!['birth_date'] as String?,
                                ),
                                roleLabel: _roleLabel(
                                  _profile!['role'] as String? ?? 'executor',
                                ),
                                onEdit:
                                    _isSelf
                                        ? () async {
                                          await context.push('/account/edit');
                                          await _loadAccountData();
                                        }
                                        : null,
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
                              _FeedbackSummaryCard(
                                avgRating: _avgRating,
                                totalFeedbacks: _totalFeedbacks,
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
                                      'Отзывы появятся после завершённых заказов.',
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

class _ProfileMainCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String? avatarUrl;
  final String? createdAt;
  final bool isSelf;
  final String ageText;
  final String roleLabel;
  final VoidCallback? onEdit;

  const _ProfileMainCard({
    required this.profile,
    required this.avatarUrl,
    required this.createdAt,
    required this.isSelf,
    required this.ageText,
    required this.roleLabel,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String? ?? 'Пользователь';

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              AppProfileAvatar(avatarUrl: avatarUrl, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.trim().isEmpty ? 'Пользователь' : name,
                      style: AppTextStyles.sectionTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(ageText, style: AppTextStyles.small),
                    const SizedBox(height: 6),
                    AppStatusPill(
                      text: roleLabel,
                      color: AppColors.accent,
                      icon: CupertinoIcons.person_crop_circle,
                    ),
                  ],
                ),
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
          _InfoRow(icon: CupertinoIcons.mail, label: 'Email', value: email),
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

class _FeedbackSummaryCard extends StatelessWidget {
  final double avgRating;
  final int totalFeedbacks;

  const _FeedbackSummaryCard({
    required this.avgRating,
    required this.totalFeedbacks,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              avgRating.toStringAsFixed(1),
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Рейтинг', style: AppTextStyles.cardTitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (index) => Icon(
                        index < avgRating.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('($totalFeedbacks)', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
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

  const _FeedbackCard({
    required this.estimate,
    required this.text,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.trim().isEmpty ? 'Без текста' : text,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < estimate
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              Text(date, style: AppTextStyles.caption),
            ],
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
        border:
            isLast
                ? null
                : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.small)),
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
