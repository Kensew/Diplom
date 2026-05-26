// lib/pages/feedback_create_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_file_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class FeedbackCreatePage extends StatefulWidget {
  final String taskId;

  const FeedbackCreatePage({required this.taskId, Key? key}) : super(key: key);

  @override
  State<FeedbackCreatePage> createState() => _FeedbackCreatePageState();
}

class _FeedbackCreatePageState extends State<FeedbackCreatePage> {
  final _textCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _alreadyExists = false;
  String? _error;

  int _rating = 5;

  String? _orderId;
  String? _reviewerId;
  String? _reviewedUserId;
  String? _reviewType;
  String? _reviewedName;
  String? _reviewedRole;
  String? _reviewedAvatarUrl;
  String? _orderTitle;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
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

  Future<bool> _hasApprovedPayment(
    String taskId,
    String? paymentStatusId,
  ) async {
    final paymentStatus = await _getRecordData(
      'payment_statuses',
      paymentStatusId,
    );

    final paymentStatusName =
        paymentStatus?['name']?.toString().trim().toLowerCase() ?? '';

    if (paymentStatusName == 'paid' || paymentStatusName == 'approved') {
      return true;
    }

    final result = await PocketBaseService.instance.pb
        .collection('payment_requests')
        .getList(page: 1, perPage: 200);

    for (final record in result.items) {
      final requestTaskId = _relationId(record.data['task_id']);
      final status = record.data['status']?.toString().trim().toLowerCase();

      if (requestTaskId == taskId && status == 'approved') {
        return true;
      }
    }

    return false;
  }

  Future<void> _loadContext() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final currentUserId = service.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      final task = await service.pb.collection('tasks').getOne(widget.taskId);

      final orderId = _relationId(task.data['order_id']);
      final executorId = _relationId(task.data['executor_id']);
      final paymentStatusId = _relationId(task.data['payment_status_id']);

      final order = await _getRecordData('orders', orderId);

      if (order == null) {
        throw 'Заказ не найден';
      }

      final customerId = _relationId(order['customer_id']);

      final paid = await _hasApprovedPayment(widget.taskId, paymentStatusId);

      if (!paid) {
        throw 'Отзыв можно оставить только после оплаты';
      }

      String? reviewedUserId;
      String? reviewType;
      String? reviewedRole;

      if (currentUserId == customerId && executorId != null) {
        reviewedUserId = executorId;
        reviewType = 'customer_to_executor';
        reviewedRole = 'Исполнитель';
      } else if (currentUserId == executorId && customerId != null) {
        reviewedUserId = customerId;
        reviewType = 'executor_to_customer';
        reviewedRole = 'Заказчик';
      } else {
        throw 'Оставить отзыв может только участник задачи';
      }

      final reviewedUser = await _getRecordData('users', reviewedUserId);

      final feedbacks = await service.pb
          .collection('feedbacks')
          .getList(page: 1, perPage: 200);

      bool exists = false;

      for (final feedback in feedbacks.items) {
        final feedbackOrderId = _relationId(feedback.data['order_id']);
        final feedbackReviewerId = _relationId(feedback.data['reviewer_id']);

        if (feedbackOrderId == orderId && feedbackReviewerId == currentUserId) {
          exists = true;
          break;
        }
      }

      _orderId = orderId;
      _reviewerId = currentUserId;
      _reviewedUserId = reviewedUserId;
      _reviewType = reviewType;
      _reviewedRole = reviewedRole;
      _alreadyExists = exists;

      _orderTitle = order['task_description'] as String? ?? 'Заказ';
      _reviewedName =
          reviewedUser?['name'] as String? ??
          reviewedUser?['email'] as String? ??
          reviewedRole;

      _reviewedAvatarUrl =
          reviewedUserId == null
              ? null
              : PocketBaseFileService.fileUrl(
                collectionName: 'users',
                recordId: reviewedUserId,
                fileValue: reviewedUser?['photo'],
              );
    } catch (e) {
      _error = 'Ошибка загрузки формы отзыва: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_saving || _alreadyExists) return;

    final orderId = _orderId;
    final reviewerId = _reviewerId;
    final reviewedUserId = _reviewedUserId;
    final reviewType = _reviewType;

    if (orderId == null ||
        reviewerId == null ||
        reviewedUserId == null ||
        reviewType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные отзыва не загружены')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await PocketBaseService.instance.pb
          .collection('feedbacks')
          .create(
            body: {
              'order_id': orderId,
              'reviewer_id': reviewerId,
              'reviewed_user_id': reviewedUserId,
              'type': reviewType,
              'estimate': _rating,
              'text': _textCtrl.text.trim(),
            },
          );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Отзыв сохранён')));

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения отзыва: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go('/tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadContext)
                  : Column(
                    children: [
                      AppTopBar(
                        title: 'Оставить отзыв',
                        subtitle: 'Оценка после оплаты заказа',
                        onBack: _goBack,
                      ),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          children: [
                            _ReviewTargetCard(
                              name: _reviewedName ?? 'Пользователь',
                              role: _reviewedRole ?? 'Участник',
                              avatarUrl: _reviewedAvatarUrl,
                              orderTitle: _orderTitle ?? 'Заказ',
                            ),
                            const SizedBox(height: 12),
                            if (_alreadyExists)
                              const AppEmptyState(
                                icon: CupertinoIcons.check_mark_circled,
                                title: 'Отзыв уже оставлен',
                                subtitle:
                                    'По одному заказу каждая сторона может оставить только один отзыв.',
                              )
                            else ...[
                              _RatingCard(
                                rating: _rating,
                                onChanged: (value) {
                                  setState(() => _rating = value);
                                },
                              ),
                              const SizedBox(height: 12),
                              _TextFeedbackCard(
                                controller: _textCtrl,
                                saving: _saving,
                              ),
                              const SizedBox(height: 12),
                              _SubmitReviewCard(
                                saving: _saving,
                                onSubmit: _submit,
                              ),
                            ],
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

class _ReviewTargetCard extends StatelessWidget {
  final String name;
  final String role;
  final String? avatarUrl;
  final String orderTitle;

  const _ReviewTargetCard({
    required this.name,
    required this.role,
    required this.avatarUrl,
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
              AppProfileAvatar(avatarUrl: avatarUrl, size: 54),
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
                    const SizedBox(height: 3),
                    Text(role, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const AppStatusPill(
                text: 'review',
                color: AppColors.accent,
                icon: CupertinoIcons.star_fill,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Text(
            orderTitle.trim().isEmpty ? 'Без описания заказа' : orderTitle,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _RatingCard({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Оценка'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;

              return CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => onChanged(value),
                child: Icon(
                  value <= rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 42,
                  color: AppColors.accent,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(child: Text('$rating из 5', style: AppTextStyles.cardTitle)),
        ],
      ),
    );
  }
}

class _TextFeedbackCard extends StatelessWidget {
  final TextEditingController controller;
  final bool saving;

  const _TextFeedbackCard({required this.controller, required this.saving});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Комментарий'),
          const SizedBox(height: 12),
          Text(
            'Коротко опишите, как прошла работа. Пишите по фактам: сроки, связь, результат, оплата.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !saving,
            minLines: 4,
            maxLines: 8,
            cursorColor: AppColors.accent,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Текст отзыва',
              hintText:
                  'Например: работа выполнена в срок, связь была хорошая...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitReviewCard extends StatelessWidget {
  final bool saving;
  final VoidCallback onSubmit;

  const _SubmitReviewCard({required this.saving, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: saving ? null : onSubmit,
            icon:
                saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(CupertinoIcons.check_mark_circled),
            label: Text(saving ? 'Сохраняем...' : 'Опубликовать отзыв'),
          ),
          const SizedBox(height: 10),
          Text(
            'После публикации отзыв появится в профиле пользователя.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
